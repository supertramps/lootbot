-- Weekly API statistics, independent of the loot/optical relay.
LootBotGuildStatistics = {}
local G=LootBotGuildStatistics
local WEEK,MONDAY=604800,345600
function G.Week(t) return math.floor((t-MONDAY)/WEEK) end
local function valid(v) return type(v)=='number' and v==v and v>=0 and v<=1e15 end
local function cleanName(v) return type(v)=='string' and #v<=100 and not v:find('[|;=,%c]') end
function G.New(db,api)
    db.weeks=db.weeks or {}
    local self={db=db,api=api,queue={},pending={},sequence=0}
    function self:Prune()
        local week=G.Week(api.now())
        for w in pairs(db.weeks) do if type(w)~='number' or w<week-3 or w>week then db.weeks[w]=nil end end
    end
    function self:Merge(name,week,first,last,start,finish)
        local now=api.now()
        if not cleanName(name) or not api.member(name) or week<G.Week(now)-3 or week>G.Week(now)
            or not valid(first) or not valid(last) or first>last or last>now+120
            or G.Week(first)~=week or G.Week(last)~=week then return false end
        local count=0
        for id,v in pairs(start) do count=count+1; if not valid(v) or not valid(finish[id]) or not valid(id) or id%1~=0 then return false end end
        if count>500 then return false end
        db.weeks[week]=db.weeks[week] or {}
        local records=db.weeks[week]
        local old=records[name]
        if not old then
            local n=0; for _ in pairs(records) do n=n+1 end
            if n>=100 then return false end
            records[name]={first=first,last=last,start=start,finish=finish}; return true
        end
        if first<old.first then old.first=first; old.start=start end
        if last>old.last then old.last=last; old.finish=finish; return true end
        return false
    end
    function self:Queue(name,week,record,target)
        local ids={}; for id in pairs(record.start) do if record.finish[id] then ids[#ids+1]=id end end
        table.sort(ids)
        local parts={}
        for _,id in ipairs(ids) do parts[#parts+1]=string.format('%d=%.0f=%.0f',id,record.start[id],record.finish[id]) end
        if #parts==0 then return end
        local payload=table.concat(parts,',')
        self.sequence=self.sequence+1
        local token=tostring(api.now())..'-'..self.sequence
        local header=table.concat({'D',token,name,week,record.first,record.last},';')..';'
        local size=255-#header-9
        if size<60 then return end
        local total=math.ceil(#payload/size)
        if total>100 or #self.queue+total>1500 then return end
        for i=1,total do self.queue[#self.queue+1]={message=header..i..';'..total..';'..payload:sub((i-1)*size+1,i*size),target=target} end
    end
    function self:Capture(snapshot)
        if not snapshot or snapshot.error or not cleanName(api.player()) then return end
        self:Prune()
        local now=api.now(); local week=G.Week(now); local name=api.player()
        local values={}
        for _,entry in ipairs(snapshot.entries or {}) do
            if not entry.hidden and valid(entry.id) and valid(entry.numericValue) then values[entry.id]=entry.numericValue end
        end
        local records=db.weeks[week] or {}; local old=records[name]
        -- New IDs get their own current-value baseline; unknown is never zero.
        local start={}
        for id,v in pairs(values) do start[id]=old and old.start[id] or v end
        local first=old and old.first or now
        if self:Merge(name,week,first,now,start,values) then
            -- Merge preserves the earlier baseline; retain newly readable IDs too.
            local record=db.weeks[week][name]
            for id,v in pairs(start) do if record.start[id]==nil then record.start[id]=v end end
            self:Queue(name,week,record)
        end
    end
    function self:Tick()
        local now=api.now()
        for key,p in pairs(self.pending) do if now-p.received>120 then self.pending[key]=nil end end
        local row=table.remove(self.queue,1)
        if row then api.send(row.message,row.target) end
    end
    function self:Receive(message,sender,channel)
        if not api.member(sender) or type(message)~='string' or #message>255 then return end
        self:Prune()
        if message=='HELLO' and channel=='GUILD' then
            self.offers=self.offers or {}
            if self.offers[sender] and api.now()-self.offers[sender]<300 then return end
            self.offers[sender]=api.now()
            if #self.queue<1500 then self.queue[#self.queue+1]={message='OFFER',target=sender} end
            return
        end
        if message=='OFFER' and self.seeking then self.seeking=false; api.send('CACHE',sender); return end
        if message=='CACHE' and channel=='WHISPER' then
            self.requests=self.requests or {}
            if self.requests[sender] and api.now()-self.requests[sender]<300 then return end
            self.requests[sender]=api.now()
            for week,records in pairs(db.weeks) do
                for name,record in pairs(records) do if api.member(name) then self:Queue(name,week,record,sender) end end
            end
            return
        end
        local token,name,w,f,l,i,n,body=message:match('^D;([^;]+);([^;]+);(%d+);(%d+);(%d+);(%d+);(%d+);(.*)$')
        w,f,l,i,n=tonumber(w),tonumber(f),tonumber(l),tonumber(i),tonumber(n)
        if not token or #token>40 or not cleanName(name) or not api.member(name) or not i or i<1 or i>n or n>100
            or (channel=='GUILD' and name~=sender) or (channel~='GUILD' and channel~='WHISPER') then return end
        local key=sender..':'..token
        local p=self.pending[key]
        if not p then
            local count=0; for _ in pairs(self.pending) do count=count+1 end
            if count>=32 then return end
            p={name=name,week=w,first=f,last=l,total=n,chunks={},received=api.now()}; self.pending[key]=p
        end
        if p.name~=name or p.week~=w or p.first~=f or p.last~=l or p.total~=n then self.pending[key]=nil; return end
        p.chunks[i]=body
        for j=1,n do if not p.chunks[j] then return end end
        self.pending[key]=nil
        local data=table.concat(p.chunks); local start,finish={},{}
        if #data>20000 or data:find('[^%d=,]') then return end
        for row in data:gmatch('[^,]+') do
            local id,a,b=row:match('^(%d+)=(%d+)=(%d+)$')
            id,a,b=tonumber(id),tonumber(a),tonumber(b)
            if not id or start[id] then return end
            start[id]=a; finish[id]=b
        end
        self:Merge(name,w,f,l,start,finish)
    end
    function self:Join()
        self.seeking=true; api.send('HELLO')
        -- Re-advertise our historical endings (including saved logout readings).
        for week,records in pairs(db.weeks) do
            if records[api.player()] then self:Queue(api.player(),week,records[api.player()]) end
        end
    end
    self:Prune()
    return self
end

-- Three changing leaderboards, mixing mishaps, progress and odd habits.
local pools={
    {{60,'DEATH TOLL','Corpse runs are still free.'},{114,'LONG WAY DOWN','The ground won again.'},{115,'HOT FOOT','Lava is not a shortcut.'},{112,'DEEP BREATH','Someone forgot to come up for air.'},{594,'HOGGER','Hogger had a good week.'}},
    {{98,'QUESTS','Jobs done. Rewards collected.'},{341,'EPIC LOOT','Some bags had a better week than others.'},{107,'ON THE HUNT','A rough week for the local wildlife.'},{345,'POTION BREAK','Keeping the alchemists in business.'},{1044,'NEED ROLLS','Apparently everyone needed it.'}},
    {{1518,'GONE FISHING','The fish did not get a vote.'},{108,'TINY TARGETS','No critter was safe.'},{1042,'FREE HUGS','Even the Horde needs a hug.'},{1065,'WAVING','Hello. Hello again.'},{1047,'FACEPALMS','That sort of week.'},{1066,'GOOD LAUGHS','At least someone found it funny.'}}
}
function G.Launch(now)
    return {id=G.Week(now),partial=true,launch=true,template=1,fields={
        masthead='ORIGINAL FORMALITIES\nWEEKLY',
        edition='FIRST ISSUE COMING MONDAY  |  ORIGINAL FORMALITIES',
        headline='A guild full of stories. Someone should write them down.',
        lead='Welcome to Original Formalities Weekly.\n\nThis week, your addon is collecting the numbers behind the guild\'s adventures. Who keeps dying? Who brings home the loot? Who spent the whole evening fishing?\n\nCome back Monday for our first proper issue. Until then, go give us something to write about.',
        leftTitle='THE MISHAPS',leftBody='Corpse runs\nBad landings\nA swim too far\nUnplanned lava baths\n\nNames will be named.',
        middleTitle='THE GOOD STUFF',middleBody='Epic loot\nQuests finished\nCreatures killed\nBiggest hits and heals\n\nCredit where it is due.',
        rightTitle='GUILD HABITS',rightBody='Fish caught\nCritters slain\nHugs, waves and laughs\nFacepalms\n\nWe have questions.'}}
end
function G.Edition(db,now)
    local current=G.Week(now)
    local week=current-1
    local records=db.weeks and db.weeks[week]
    local partial=false
    if not records or not next(records) then
        for earlier=current-2,current-3,-1 do
            local previous=db.weeks and db.weeks[earlier]
            if previous and next(previous) then week=earlier; records=previous; break end
        end
    end
    if not records or not next(records) then week=current; records=db.weeks and db.weeks[week]; partial=true end
    if not records or not next(records) then return G.Launch(now) end
    if partial then return G.Launch(now) end
    local result={id=week,template=week%3+1,partial=partial,fields={},metrics={}}
    local participants=0; for _ in pairs(records) do participants=participants+1 end
    local field=result.fields
    field.masthead='ORIGINAL FORMALITIES\nWEEKLY'
    field.edition=(partial and 'THIS WEEK SO FAR' or 'WEEKLY GUILD EDITION')..(date and '  |  '..date('!%d %b',MONDAY+week*WEEK) or '')..'  |  '..participants..' CHARACTERS'
    local names={'left','middle','right'}
    local notes={}
    local star
    for column,pool in ipairs(pools) do
        local chosen=pool[(week+column-1)%#pool+1]
        -- Rotate through active counters, rather than repeatedly falling back
        -- to the first busy counter in the full catalogue.
        local active={}
        for _,candidate in ipairs(pool) do
            local positive=false
            for _,r in pairs(records) do local a,b=r.start[candidate[1]],r.finish[candidate[1]]; if a and b and b>a then positive=true end end
            if positive then active[#active+1]=candidate end
        end
        if #active>0 then chosen=active[(week+column-1)%#active+1] end
        local board,total={},0
        for name,r in pairs(records) do
            local a,b=r.start[chosen[1]],r.finish[chosen[1]]
            if a and b and b>=a and r.last>r.first then
                local delta=b-a
                board[#board+1]={name=name:match('^[^-]+') or name,value=delta}; total=total+delta
            end
        end
        table.sort(board,function(a,b) return a.value==b.value and a.name<b.name or a.value>b.value end)
        if not star and board[1] and board[1].value>0 then star={id=chosen[1],name=board[1].name,value=board[1].value} end
        local lines={'THIS WEEK',''}
        for i=1,math.min(3,#board) do lines[#lines+1]=i..'  '..board[i].name..'  '..string.format('%.0f',board[i].value) end
        if #board==0 then lines[#lines+1]='Waiting for two readings.' end
        lines[#lines+1]=''; lines[#lines+1]='Guild total: '..string.format('%.0f',total)
        field[names[column]..'Title']=chosen[2]; field[names[column]..'Body']=table.concat(lines,'\n')
        result.metrics[column]=chosen[1]
        notes[#notes+1]=chosen[3]
    end
    field.headline=notes[1]
    local phrases={
        [60]='%s died %s times. Still playing.',[114]='%s fell to their death %s times.',
        [115]='%s burned to death %s times.',[112]='%s drowned %s times.',[594]='Hogger killed %s %s times.',
        [98]='%s got %s quests done.',[341]='%s brought home %s epics.',[107]='%s killed %s creatures.',
        [345]='%s drank %s health potions.',[1044]='%s rolled need %s times.',
        [1518]='%s caught %s fish. Busy week.',[108]='%s killed %s critters. Why?',
        [1042]='%s gave out %s hugs.',[1065]='%s waved %s times.',[1047]='%s facepalmed %s times.',[1066]='%s laughed %s times.'
    }
    if star then field.headline=string.format(phrases[star.id],star.name,string.format('%.0f',star.value)) end
    -- Highest-hit/heal statistics are records, not additive weekly counters.
    local recordStar
    for name,r in pairs(records) do
        for _,id in ipairs({193,189}) do
            local a,b=r.start[id],r.finish[id]
            if a and b and b>a and (not recordStar or b>recordStar.value or (b==recordStar.value and name<recordStar.name)) then
                recordStar={name=name,id=id,value=b}
            end
        end
    end
    if recordStar then
        local name=recordStar.name:match('^[^-]+') or recordStar.name
        field.headline=name..' landed a '..string.format('%.0f',recordStar.value)..(recordStar.id==193 and ' hit.' or ' heal.')
        notes[#notes+1]=name..' beat their previous '..(recordStar.id==193 and 'biggest hit' or 'biggest heal')..' record.'
    end
    field.lead=table.concat({notes[2],notes[3],
        'Weekly changes between saved readings. Late joiners and time offline can leave gaps.',
        partial and 'First week in progress. New edition Monday (UTC).' or 'Last week\'s activity. New edition Monday (UTC).'},'\n\n')
    if recordStar then field.lead=notes[#notes]..'\n\n'..field.lead end
    return result
end
