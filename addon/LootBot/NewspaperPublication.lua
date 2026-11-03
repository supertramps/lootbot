-- One immutable edition per week, copied through authenticated guild addon chat.
-- Guild members are trusted peers; the checksum detects corruption, not forgery.
LootBotNewspaperPublication={}
local P=LootBotNewspaperPublication
local WEEK,MONDAY,CHUNK=604800,345600,180
local textures={front='NewsletterFront1.png',frontLedger='NewsletterFront2.png',inside='NewsletterInside.png',back='NewsletterBack.png'}
local function name(v) return type(v)=='string' and #v>0 and #v<=100 and not v:find('[|;%c]') end
local function hash(v) return string.format('%.0f',LootBotProtocol.adler32(v)%4294967296.0) end
local function escape(v) return (tostring(v):gsub('[%%%z\1-\31\127-\255]',function(c) return string.format('%%%02X',c:byte()) end)) end
local function unescape(v)
    local bad=false
    if v:match('%%$') or v:match('%%.$') then return nil end
    v=v:gsub('%%(..)',function(h) if not h:match('^%x%x$') then bad=true;return '' end;return string.char(tonumber(h,16)) end)
    if bad or v:find('[%z\1-\8\11\12\14-\31]') then return nil end
    return v
end
local function split(line)
    local fields={}
    for v in (line..'\t'):gmatch('(.-)\t') do local decoded=unescape(v);if not decoded then return nil end;fields[#fields+1]=decoded end
    return fields
end
function P.Encode(edition,publisher,printedAt)
    if edition.demo or edition.launch or not name(publisher) then return nil end
    local lines={table.concat({'NP1',edition.id,MONDAY+(edition.id+1)*WEEK,printedAt,escape(publisher)},'\t')}
    for _,page in ipairs(edition.pages or {}) do
        lines[#lines+1]=table.concat({'P',escape(page.name),page.layout,page.texture},'\t')
        local keys={};for key in pairs(page.fields) do keys[#keys+1]=key end;table.sort(keys)
        for _,key in ipairs(keys) do lines[#lines+1]='F\t'..key..'\t'..escape(page.fields[key]) end
    end
    local people={};for player in pairs(edition.readings or {}) do people[#people+1]=player end;table.sort(people)
    for _,player in ipairs(people) do
        local ids={};for id in pairs(edition.readings[player]) do ids[#ids+1]=id end;table.sort(ids)
        local values={};for _,id in ipairs(ids) do values[#values+1]=id..'='..string.format('%.0f',edition.readings[player][id]) end
        lines[#lines+1]='V\t'..escape(player)..'\t'..table.concat(values,',')
    end
    local body=table.concat(lines,'\n')
    if #body>60000 then return nil end
    return body
end
function P.Decode(body,now)
    if type(body)~='string' or #body>60000 then return nil end
    local header,edition,page,lineCount
    lineCount=0
    for line in (body..'\n'):gmatch('(.-)\n') do
        lineCount=lineCount+1;if lineCount>400 then return nil end
        local f=split(line);if not f then return nil end
        if not header then
            local week,scheduled,printed=tonumber(f[2]),tonumber(f[3]),tonumber(f[4])
            if #f~=5 or f[1]~='NP1' or not week or week%1~=0 or week<LootBotGuildStatistics.Week(now)-4 or week>=LootBotGuildStatistics.Week(now)
                or scheduled~=MONDAY+(week+1)*WEEK or not printed or printed<scheduled or printed>=scheduled+WEEK or printed>now+120 or not name(f[5]) then return nil end
            edition={id=week,scheduledAt=scheduled,publishedAt=printed,publisher=f[5],pages={},readings={}};header=true
        elseif f[1]=='P' then
            if #f~=4 or #edition.pages>=8 or #f[2]>60 or textures[f[3]]~=f[4] then return nil end
            if #edition.pages==0 and f[3]~='front' and f[3]~='frontLedger' then return nil end
            page={name=f[2],layout=f[3],texture=f[4],fields={}};edition.pages[#edition.pages+1]=page
        elseif f[1]=='F' then
            if #f~=3 or not page or #f[2]>32 or not f[2]:match('^[A-Za-z]+$') or #f[3]>2048 or page.fields[f[2]]~=nil then return nil end
            page.fields[f[2]]=f[3]
        elseif f[1]=='V' then
            if #f~=3 or not name(f[2]) or edition.readings[f[2]] then return nil end
            local values,count={},0
            for pair in f[3]:gmatch('[^,]+') do
                local id,value=pair:match('^(%d+)=(%d+)$');id,value=tonumber(id),tonumber(value)
                if not id or id>1000000000 or not value or value>1e15 or values[id]~=nil then return nil end
                count=count+1;if count>40 then return nil end;values[id]=value
            end
            edition.readings[f[2]]=values
        else return nil end
    end
    if not edition or #edition.pages<2 or edition.pages[#edition.pages].layout~='back' then return nil end
    return edition
end
function P.New(db,api)
    db.issues=db.issues or {}
    db.knownHashes=db.knownHashes or {}
    local self={db=db,api=api,controls={},broadcast={},streams={},pending={},requests={},hello=-100,role=-100,lastSend=-100,
        currentWeek=LootBotGuildStatistics.Week(api.now()),notBefore=api.now()+60,lastData=api.now(),revision=api.revision(),cursor=0}
    local function clock() return api.clock and api.clock() or api.now() end
    function self:Prune()
        local current=LootBotGuildStatistics.Week(api.now())
        for week in pairs(db.issues) do if week<current-4 or week>=current then db.issues[week]=nil end end
        for week in pairs(db.knownHashes) do if week<current-4 or week>=current then db.knownHashes[week]=nil end end
        for key,p in pairs(self.pending) do if api.now()-p.at>600 then self.pending[key]=nil end end
    end
    function self:Control(message,target,delay)
        if #self.controls<128 then self.controls[#self.controls+1]={message=message,target=target,due=clock()+(delay or 0)} end
    end
    function self:Latest()
        local selected
        for week,issue in pairs(db.issues) do if not selected or week>selected.edition.id then selected=issue end end
        return selected
    end
    function self:Store(body,expectedHash,expectedPublisher)
        if hash(body)~=expectedHash then return false end
        local edition=P.Decode(body,api.now())
        if not edition or (expectedPublisher and edition.publisher~=expectedPublisher) or (db.publisher and edition.publisher~=db.publisher) then return false end
        if db.knownHashes[edition.id] and db.knownHashes[edition.id]~=expectedHash then return false end
        local old=db.issues[edition.id]
        if old then return old.hash==expectedHash end -- published issues never change
        db.publisher=edition.publisher
        db.knownHashes[edition.id]=expectedHash
        db.issues[edition.id]={payload=body,hash=expectedHash,edition=edition}
        if not db.lastPrintedWeek or edition.id>db.lastPrintedWeek then db.lastPrintedWeek=edition.id;db.printedReadings=edition.readings end
        if api.changed then api.changed() end
        return true
    end
    function self:Offer(target)
        local latest=self:Latest()
        if latest then self:Control(table.concat({'O',latest.edition.publisher,latest.edition.id,latest.hash},';'),target,
            target and (LootBotProtocol.adler32(api.player()..target)%6)/2 or 0) end
    end
    function self:Join() self:Control('H');self.hello=api.now() end
    function self:Get()
        local latest=self:Latest()
        if latest then return latest.edition end
        local week=LootBotGuildStatistics.Week(api.now())
        if not self.waiting or self.waiting.id~=week then self.waiting=LootBotGuildStatistics.Launch(api.now());self.waiting.waiting=true end
        self.waiting.publisher=db.publisher
        return self.waiting
    end
    function self:Receive(message,sender,channel)
        if sender==api.player() or not api.member(sender) or type(message)~='string' or #message>255 then return end
        if message=='H' and channel=='GUILD' then
            if not self.requests[sender] or api.now()-self.requests[sender]>=30 then self.requests[sender]=api.now();self:Offer(sender) end
            return
        end
        if message=='R' and channel=='GUILD' then
            if not db.publisher and api.knownRelay(sender) then db.publisher=sender end
            return
        end
        local publisher,w,h=message:match('^O;([^;]+);(%d+);(%d+)$')
        if publisher and (channel=='WHISPER' or channel=='GUILD') then
            w=tonumber(w)
            if not name(publisher) or (db.publisher and db.publisher~=publisher) or w<LootBotGuildStatistics.Week(api.now())-4 or w>=LootBotGuildStatistics.Week(api.now()) or db.issues[w] then return end
            if db.knownHashes[w] and db.knownHashes[w]~=h then return end
            db.knownHashes[w]=h
            if self.downloading and api.now()-self.downloading.at<30 then return end
            self.downloading={sender=sender,week=w,hash=h,publisher=publisher,at=api.now()}
            self:Control('Q;'..w..';'..h,sender);return
        end
        local qweek,qhash=message:match('^Q;(%d+);(%d+)$')
        if qweek and channel=='WHISPER' then
            local issue=db.issues[tonumber(qweek)]
            if not issue or issue.hash~=qhash then return end
            local count=0;for _ in pairs(self.streams) do count=count+1 end
            if count>=8 and not self.streams[sender] then return end
            self.streams[sender]={week=tonumber(qweek),hash=qhash,body=issue.payload,index=1,last=-100,retries=0};return
        end
        local aweek,ahash,index=message:match('^K;(%d+);(%d+);(%d+)$')
        if aweek and channel=='WHISPER' then
            local stream=self.streams[sender]
            if stream and stream.week==tonumber(aweek) and stream.hash==ahash and stream.waiting==tonumber(index) then
                stream.index=stream.index+1;stream.waiting=nil;stream.retries=0
                if (stream.index-1)*CHUNK>=#stream.body then self.streams[sender]=nil end
            end
            return
        end
        local week,digest,i,total,part=message:match('^D;(%d+);(%d+);(%d+);(%d+);(.*)$')
        week,i,total=tonumber(week),tonumber(i),tonumber(total)
        if not week or (channel~='GUILD' and channel~='WHISPER') or total<1 or total>334 or i<1 or i>total or #part>CHUNK then return end
        if week<LootBotGuildStatistics.Week(api.now())-4 or week>=LootBotGuildStatistics.Week(api.now()) then return end
        if channel=='GUILD' and sender~=db.publisher and not api.knownRelay(sender) then return end
        if channel=='WHISPER' and (not self.downloading or self.downloading.sender~=sender or self.downloading.week~=week or self.downloading.hash~=digest) then return end
        if channel=='WHISPER' then self.downloading.at=api.now() end
        if db.issues[week] then
            if db.issues[week].hash==digest and channel=='WHISPER' then api.send('K;'..week..';'..digest..';'..i,sender) end
            return
        end
        local key=sender..':'..week..':'..digest
        local assembly=self.pending[key]
        if not assembly then
            local count=0;for _ in pairs(self.pending) do count=count+1 end;if count>=8 then return end
            assembly={at=api.now(),chunks={},total=total};self.pending[key]=assembly
        end
        if assembly.total~=total then self.pending[key]=nil;return end
        assembly.chunks[i]=part
        if channel=='WHISPER' then api.send('K;'..week..';'..digest..';'..i,sender) end
        for j=1,total do if not assembly.chunks[j] then return end end
        self.pending[key]=nil
        local expected=channel=='GUILD' and sender or self.downloading.publisher
        if self:Store(table.concat(assembly.chunks),digest,expected) then self.downloading=nil;self:Offer() end
    end
    function self:Tick()
        self:Prune()
        local now=api.now();local week=LootBotGuildStatistics.Week(now)
        if week~=self.currentWeek then self.currentWeek=week;self.notBefore=now+60;self.lastData=now end
        if api.revision()~=self.revision then self.revision=api.revision();self.lastData=now end
        if self.downloading and now-self.downloading.at>=30 then self.downloading=nil;self.hello=-100 end
        if now-self.hello>=60 then self:Join() end
        if api.canPublish() and (not db.publisher or db.publisher==api.player()) then
            db.publisher=api.player()
            if now-self.role>=30 then self.role=now;self:Control('R') end
            if (not api.ready or api.ready()) and not db.issues[week-1] and not db.knownHashes[week-1] and now>=self.notBefore and (now-self.lastData>=15 or now>=self.notBefore+540) then
                local draft,readings=api.build(db.printedReadings or {})
                if draft and not draft.launch and draft.id==week-1 and not draft.demo then
                    draft.readings=readings or {}
                    if LootBotNewspaperEdition then LootBotNewspaperEdition.PublicationDate(draft,now) end
                    local body=P.Encode(draft,api.player(),now)
                    local digest=body and hash(body)
                    if body and self:Store(body,digest,api.player()) then
                        local total=math.ceil(#body/CHUNK)
                        for i=1,total do self.broadcast[#self.broadcast+1]='D;'..draft.id..';'..digest..';'..i..';'..total..';'..body:sub((i-1)*CHUNK+1,i*CHUNK) end
                    end
                end
            end
        end
        if clock()-self.lastSend<0.5 then return end
        for i,control in ipairs(self.controls) do
            if control.due<=clock() then table.remove(self.controls,i);api.send(control.message,control.target);self.lastSend=clock();return end
        end
        if #self.broadcast>0 then api.send(table.remove(self.broadcast,1));self.lastSend=clock();return end
        local targets={};for target in pairs(self.streams) do targets[#targets+1]=target end;table.sort(targets)
        if #targets==0 then return end
        self.cursor=self.cursor%#targets+1
        local target=targets[self.cursor];local stream=self.streams[target]
        if not stream.waiting or clock()-stream.last>=2 then
            if stream.retries>=8 then self.streams[target]=nil;return end
            local total=math.ceil(#stream.body/CHUNK)
            api.send('D;'..stream.week..';'..stream.hash..';'..stream.index..';'..total..';'..stream.body:sub((stream.index-1)*CHUNK+1,stream.index*CHUNK),target)
            stream.waiting=stream.index;stream.last=clock();stream.retries=stream.retries+1;self.lastSend=clock()
        end
    end
    self:Prune();return self
end
