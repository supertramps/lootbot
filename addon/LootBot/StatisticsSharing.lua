-- Guild-only transport. Never touches the optical marker or cloud relay.
local prefix='LootBotNews2'
local paperPrefix='LootBotPaper1'
local driver=CreateFrame('Frame','LootBotStatisticsDriver')
local elapsed,joined=0,false
local engine,roster,own=nil, {}, nil
local publication,sync,lastRequest
local function knownRelay(name)
    local live=LootBotRelay.Live and LootBotRelay.Live()
    return live and (live:knownRelay(name) or (name==own and live.db.relay)) or false
end
local function canPublish()
    if not publication or not roster[own] then return false end
    local live=LootBotRelay.Live and LootBotRelay.Live()
    local publisher=publication.db.publisher
    return live and live.db.relay and (publisher==own or (not publisher and live:activeRelay()==own)) or false
end
local function canonical(name)
    if not name then return nil end
    return LootBotProtocol.canonical(name,GetRealmName())
end
local function members()
    roster={}
    for i=1,GetNumGuildMembers() do
        local name=GetGuildRosterInfo(i)
        name=canonical(name)
        if name then roster[name]=true end
    end
end
local function initialise()
    if not IsInGuild() then engine=nil; publication=nil; sync=nil; return end
    local guild=GetGuildInfo('player')
    if not guild then return end
    LootBotDB=LootBotDB or {}; LootBotDB.guildStatistics=LootBotDB.guildStatistics or {}
    local key=GetRealmName()..':'..guild
    if engine and engine.key==key then return end
    LootBotDB.guildStatistics[key]=LootBotDB.guildStatistics[key] or {}
    own=canonical(LootBotProtocol.localPlayerName()); joined=false; sync=nil; lastRequest=nil
    engine=LootBotGuildStatistics.New(LootBotDB.guildStatistics[key],{
        now=GetServerTime,player=function() return own end,
        member=function(name) return roster[canonical(name)]==true end,
        send=function(message,target)
            if LootBotDB.shareStatistics==false or not IsInGuild() then return end
            LootBotProtocol.sendAddon(prefix,message,target and 'WHISPER' or 'GUILD',target)
        end
    })
    engine.key=key
    if LootBotNewspaperPublication then
        engine.db.publication=engine.db.publication or {}
        publication=LootBotNewspaperPublication.New(engine.db.publication,{
            now=GetServerTime,clock=GetTime,player=function() return own end,
            member=function(name) return roster[canonical(name)]==true end,
            knownRelay=knownRelay,canPublish=canPublish,
            send=function(message,target)
                if IsInGuild() then LootBotProtocol.sendAddon(paperPrefix,message,target and 'WHISPER' or 'GUILD',target) end
            end,
        })
    end
end
local function snapshot()
    return LootBotGuildStatistics.NewspaperValues(LootBotStatisticsProbe.Capture(false))
end
local function sortedNames(set)
    local names={}
    for name in pairs(set) do names[#names+1]=name end
    table.sort(names)
    return names
end
local function draft(now)
    local from=engine.db.manualPrintedAt or (publication:Latest() and publication:Latest().edition.publishedAt)
    if not from then
        for _,records in pairs(engine.db.weeks) do
            for _,record in pairs(records) do from=math.min(from or now,record.first) end
        end
    end
    return LootBotGuildStatistics.PublicationDraft(engine.db,now,
        engine.db.manualPrintedReadings or publication.db.printedReadings or {},
        function(name) return roster[name]==true end,from or now)
end
function LootBotGuildStatistics.ManualNews(action,say)
    if not canPublish() then say('Logga in med tidningens utgivarkaraktär och aktivera relay.');return end
    local now=GetServerTime()
    if action=='sync' then
        if LootBotDB.shareStatistics==false then say('Statistikdelning är pausad. Kör /lootbot stats on först.');return end
        if sync then say('En synk pågår redan. Vänta på kvittot.');return end
        local token=tostring(now)
        sync={token=token,started=now,ends=GetTime()+60,responded={},say=say}
        local values=snapshot()
        if next(values) and engine:Merge(own,LootBotGuildStatistics.Week(now),now,now,values,values) then
            sync.responded[own]=true
        end
        LootBotProtocol.sendAddon(prefix,'S;'..token,'GUILD')
        say('Samlar in statistik i 60 sekunder. Du får ett kvitto när synken är klar.')
        return
    end
    if action=='publish' and sync then say('Vänta på synkkvittot innan du publicerar.');return end
    local edition,readings=draft(now)
    if not next(readings) then say('Inga sparade siffror ännu. Kör /lootbot news sync.');return end
    if action=='preview' then
        LootBotNewspaperEdition.PublicationDate(edition,now)
        for _,page in ipairs(edition.pages) do
            page.fields.edition='FÖRHANDSVISNING  |  '..LootBotNewspaperEdition.Date(now)..'  |  ORIGINAL FORMALITIES'
        end
        LootBotNewsletterPreview.Show(edition)
        return
    end
    if not publication:Publish(edition) then say('Numret kunde inte publiceras. Försök igen om en stund.');return end
    engine.db.manualPrintedAt=now
    engine.db.manualPrintedReadings=readings
    say('Numret är publicerat. Guildies får ett ! på ikonen när det är hämtat.')
end
function LootBotGuildStatistics.PublicationStatus()
    if not publication then return 'No guild publication is loaded. Restart WoW after updating all addon files.' end
    local latest=publication:Latest()
    local text='Publisher: '..(publication.db.publisher or 'waiting for a relay character')..'.'
    if latest then text=text..' Latest paper: '..LootBotNewspaperEdition.Date(latest.edition.publishedAt)..'.'
    else text=text..' Waiting for the first printed issue.' end
    local count=0; for _ in pairs(engine and engine.db.checkpoints or {}) do count=count+1 end
    return text..' Statistics received: '..count..' characters.'
end
function LootBotGuildStatistics.CoverageStatus()
    if not engine then return {'Ingen guildstatistik inläst än.'} end
    local lines={LootBotGuildStatistics.PublicationStatus()}
    local latest=publication and publication:Latest()
    local printed=engine.db.manualPrintedReadings or (latest and latest.edition.readings) or {}
    local names={};for name in pairs(roster) do names[#names+1]=name end;table.sort(names)
    for _,name in ipairs(names) do
        local checkpoint=engine.db.checkpoints[name]
        local last=0
        for _,stamp in pairs(checkpoint and checkpoint.times or {}) do last=math.max(last,stamp) end
        local state=last>0 and ('senaste data för '..math.floor(math.max(0,GetServerTime()-last)/60)..' min sedan') or 'inga data mottagna'
        lines[#lines+1]=name..': '..state..(printed[name] and '; med i publicerade underlaget.' or '; inte i publicerade underlaget.')
    end
    return lines
end
function LootBotGuildStatistics.CurrentEdition()
    local now=GetServerTime()
    if not engine or not engine.db then return LootBotGuildStatistics.Launch(now) end
    if publication then return publication:Get() end
    -- A missing publication module must not silently show a local draft as
    -- though it were the shared issue.
    local waiting=LootBotGuildStatistics.Launch(now);waiting.waiting=true;return waiting
end
function LootBotGuildStatistics.Sharing(enabled)
    LootBotDB=LootBotDB or {}; LootBotDB.shareStatistics=enabled
    if engine then engine.queue={}; engine.pending={} end
    if not enabled then sync=nil end
end
for _,event in ipairs({'PLAYER_LOGIN','CHAT_MSG_ADDON','GUILD_ROSTER_UPDATE','PLAYER_GUILD_UPDATE'}) do driver:RegisterEvent(event) end
local function receiveStats(message,sender,channel)
    if not sender or sender==own or not roster[sender] or type(message)~='string' then return end
    local token=message:match('^S;(%d+)$')
    if token and channel=='GUILD' then
        local now=GetServerTime()
        local requestedAt=tonumber(token)
        local publisher=publication and publication.db.publisher
        if not publication or (publisher and publisher~=sender) or (not publisher and not knownRelay(sender))
            or math.abs(now-requestedAt)>30 or (lastRequest and now-lastRequest<30) then return end
        lastRequest=now
        local values=snapshot()
        engine:Queue(own,LootBotGuildStatistics.Week(now),{first=now,last=now,start=values,finish=values},sender,token)
        return
    end
    if not sync or channel~='WHISPER' or GetTime()>=sync.ends or sync.responded[sender] then return end
    local replyToken,player,_,first=message:match('^D;([^;]+);([^;]+);(%d+);(%d+);')
    if replyToken~=sync.token or player~=sender or tonumber(first)<sync.started-5 then return end
    if engine:Receive(message,sender,channel) then sync.responded[sender]=true end
end
driver:SetScript('OnEvent',function(_,event,received,message,channel,sender)
    if event=='CHAT_MSG_ADDON' then
        if (received~=prefix and received~=paperPrefix) or (issecretvalue and (issecretvalue(message) or issecretvalue(sender))) then return end
        local name=canonical(sender)
        if name and not roster[name] and C_GuildInfo and C_GuildInfo.MemberExistsByName
            and C_GuildInfo.MemberExistsByName(sender)==true then roster[name]=true end
        if received==prefix and engine and LootBotDB.shareStatistics~=false then receiveStats(message,name,channel) end
        if received==paperPrefix and publication then publication:Receive(message,canonical(sender),channel) end
    else
        if event=='PLAYER_LOGIN' then
            C_ChatInfo.RegisterAddonMessagePrefix(prefix)
            C_ChatInfo.RegisterAddonMessagePrefix(paperPrefix)
            if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
        end
        members(); initialise()
    end
end)
driver:SetScript('OnUpdate',function(_,delta)
    elapsed=elapsed+delta
    if elapsed<0.5 then return end
    elapsed=0
    if not engine or not engine.db or not roster[own] then return end
    if not joined then
        joined=true
        if publication then publication:Join() end
    end
    if sync and GetTime()>=sync.ends then
        local names=sortedNames(sync.responded)
        sync.say('Synk klar. '..#names..' svar. Kör /lootbot newspaper coverage för att se alla sparade avläsningar.')
        for i=1,#names,6 do sync.say('Svarade: '..table.concat(names,', ',i,math.min(i+5,#names))) end
        sync=nil
    end
    if LootBotDB.shareStatistics~=false then engine:Tick() end
    if publication then publication:Tick() end
    if LootBotNewsletterPreview and LootBotNewsletterPreview.UpdateBadge then LootBotNewsletterPreview.UpdateBadge() end
end)
