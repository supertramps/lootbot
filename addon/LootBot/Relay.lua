-- Transport-independent state machine. No chat text is sent, only addon messages.
LootBotRelay = {}
local R, P = LootBotRelay, LootBotProtocol
local RETENTION, OWN_LIMIT, INBOX_LIMIT = 30*86400, 5000, 25000

function R.new(db, api)
    db.own = db.own or {}; db.inbox = db.inbox or {}; db.cursors = db.cursors or {}
    db.milestones = db.milestones or {}; db.counter = db.counter or 0
    local self = { db=db, api=api, outgoing={}, streams={}, relays={}, seen={}, offers={},
        lastSend=-10, lastHello=-100, optical={}, opticalSeen={}, current=nil, guild=api.guild() }
    setmetatable(self, {__index=R})
    self:prune()
    return self
end
function R:prune()
    local now = self.api.now()
    for _, entry in ipairs({{self.db.own,OWN_LIMIT},{self.db.inbox,INBOX_LIMIT}}) do
        local list, limit = entry[1], entry[2]
        for i=#list,1,-1 do if list[i].timestamp < now-RETENTION then table.remove(list,i) end end
        while #list > limit do table.remove(list,1) end
    end
    self.seen={}
    for _, e in ipairs(self.db.inbox) do self.seen[e.player..':'..e.id]=true end
end
function R:queue(message, target, delay)
    if #self.outgoing >= 500 then return end -- bounded; stop-and-wait will retry data
    self.outgoing[#self.outgoing+1]={message=message,target=target,due=self.api.time()+(delay or 0)}
end
function R:activeRelay()
    local names = {}
    for name, stamp in pairs(self.relays) do
        if self.api.time()-stamp < 75 then names[#names+1]=name else self.relays[name]=nil end
    end
    if self.db.relay then names[#names+1]=self.api.player end
    table.sort(names)
    return names[1]
end
function R:isActive() return self.db.relay end
function R:knownRelay(name) return self.relays[name] and self.api.time()-self.relays[name]<75 end
function R:addOptical(event)
    -- The relay never renders ordinary loot below Rare. This protects relays
    -- during a mixed-addon upgrade; the source addon applies its own higher
    -- personal threshold before an event reaches this point.
    if event.kind=='loot' and not event.test and event.quality<3 then return end
    local key=event.player..':'..event.id
    if not self.opticalSeen[key] then
        self.opticalSeen[key]=true
        self.optical[#self.optical+1]={event=event,due=self.api.time(),repeats=2}
    end
end
function R:syncOptical()
    self:prune()
    self.optical={}; self.opticalSeen={}; self.current=nil
    for _, list in ipairs({self.db.own,self.db.inbox}) do
        for _, e in ipairs(list) do if e.guild==self.guild then self:addOptical(e) end end
    end
end
function R:purgeOwnBelow(quality)
    local kept={}
    for _, e in ipairs(self.db.own) do
        if e.kind~='loot' or e.test or e.quality>=quality then kept[#kept+1]=e end
    end
    self.db.own=kept
    -- Streams hold indexes into db.own. Restart them rather than leaving a
    -- sender waiting for an item that was deliberately discarded.
    self.streams={}; self:syncOptical()
end
function R:setRelay(value)
    self.db.relay=value; self.lastHello=-100
    if value then self:syncOptical() else self.optical={}; self.current=nil; self.api.draw(nil) end
end
function R:record(event)
    self.db.counter=self.db.counter+1
    event.id=event.id or (self.api.guid..'-'..self.api.now()..'-'..self.db.counter)
    event.player=self.api.player; event.guild=self.guild; event.timestamp=event.timestamp or self.api.now()
    event.itemId=event.itemId or 0; event.quality=event.quality or 0; event.quantity=event.quantity or 0
    event.itemName=event.itemName or ''; event.level=event.level or 0; event.test=event.test or false
    if event.kind=='loot' and not event.test and event.quality<3 then return nil end
    self.db.own[#self.db.own+1]=event
    if #self.db.own>OWN_LIMIT then table.remove(self.db.own,1); self.streams={} end
    if self.db.relay then self:addOptical(event) end
    for name in pairs(self.relays) do
        if self:knownRelay(name) and name~=self.api.player and not self.streams[name] then self:queue('O',name) end
    end
    return event
end
function R:levelUp(level)
    if type(level)~='number' or level%10~=0 or level<10 or level>200 or self.db.milestones[level] then return end
    self.db.milestones[level]=true
    return self:record({kind='level',level=level,id='L-'..self.api.guid..'-'..level})
end
function R:receive(message, channel, sender)
    if not self.guild or sender==self.api.player or not self.api.member(sender) then return end
    if channel=='GUILD' and message=='R3' then
        self.relays[sender]=self.api.time()
        if not self.streams[sender] then
            self:queue('O',sender,(P.adler32(self.api.player)%20)/10)
        end
        return
    end
    if channel~='WHISPER' then return end
    if message=='O' and self:isActive() then
        if self.offers[sender] and self.api.time()-self.offers[sender]<5 then return end
        self.offers[sender]=self.api.time()
        self:queue('Q\t'..(self.db.cursors[self.guild..':'..sender] or ''),sender)
    elseif message:sub(1,2)=='Q\t' and self:knownRelay(sender) then
        local cursor=message:sub(3); local index=1
        for i,e in ipairs(self.db.own) do if e.id==cursor and e.guild==self.guild then index=i+1; break end end
        self.streams[sender]={index=index, sentAt=-10, retries=0}
    elseif message:sub(1,2)=='A\t' then
        local stream=self.streams[sender]
        if stream and stream.waiting==message:sub(3) then
            stream.index=stream.index+1; stream.waiting=nil; stream.retries=0
        end
    elseif message:sub(1,2)=='E\t' and self:isActive() then
        local event=P.parseWire(message,sender,self.api.now())
        if not event then return end
        -- Acknowledge obsolete sub-Rare traffic so an old sender does not
        -- retry forever, but never save or render it.
        if event.kind=='loot' and not event.test and event.quality<3 then
            self.db.cursors[self.guild..':'..sender]=event.id; self:queue('A\t'..event.id,sender); return
        end
        event.guild=self.guild
        local key=sender..':'..event.id
        if not self.seen[key] then
            self.seen[key]=true; self.db.inbox[#self.db.inbox+1]=event; self:addOptical(event)
            if #self.db.inbox>INBOX_LIMIT then local old=table.remove(self.db.inbox,1); self.seen[old.player..':'..old.id]=nil end
        end
        -- ACK means stored in this addon's inbox, NOT delivered to Discord.
        self.db.cursors[self.guild..':'..sender]=event.id
        self:queue('A\t'..event.id,sender)
    end
end
function R:tick()
    local time=self.api.time()
    if self.api.guild()~=self.guild then
        self.guild=self.api.guild(); self.streams={}; self.relays={}; self.outgoing={}; self.db.cursors={}
        self:syncOptical(); self.lastHello=-100
    end
    if self.db.relay and self.guild and time-self.lastHello>=30 then
        self.lastHello=time; self:queue('R3',nil)
    end
    for target,stream in pairs(self.streams) do
        if not self:knownRelay(target) then self.streams[target]=nil
        elseif not stream.waiting or time-stream.sentAt>=15 then
            if stream.retries>=5 then self.streams[target]=nil
            else
                local event=self.db.own[stream.index]
                while event and event.guild~=self.guild do stream.index=stream.index+1; event=self.db.own[stream.index] end
                if event then
                    local data=P.wire(event)
                    if data then
                        self:queue(data,target); stream.waiting=event.id; stream.sentAt=time; stream.retries=stream.retries+1
                    else stream.index=stream.index+1 end
                end
            end
        end
    end
    if self.guild and time-self.lastSend>=0.5 then
        for i,entry in ipairs(self.outgoing) do
            if entry.due<=time then
                table.remove(self.outgoing,i); self.api.send(entry.message,entry.target); self.lastSend=time; break
            end
        end
    end
    if not self:isActive() then self.api.draw(nil); return end
    if self.current and time<self.current.untilTime then return end
    self.current=nil
    local selected=nil
    for i,entry in ipairs(self.optical) do
        if entry.due<=time then
            selected=selected or i
            if entry.event.timestamp>=self.api.now()-90 then selected=i; break end
        end
    end
    if selected then
        local entry=table.remove(self.optical,selected)
        self.current={event=entry.event,untilTime=time+1.6}
        self.api.draw(P.packet(entry.event))
        if entry.repeats>0 then
            self.optical[#self.optical+1]={event=entry.event,due=time+15,repeats=entry.repeats-1}
        end
    else self.api.draw(nil) end
end
