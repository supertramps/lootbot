-- Guild-only transport. Never touches the optical marker or cloud relay.
local prefix='LootBotNews1'
local paperPrefix='LootBotPaper1'
local driver=CreateFrame('Frame','LootBotStatisticsDriver')
local elapsed,nextCapture,joined=0,0,false
local engine,roster,own=nil, {}, nil
local publication
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
    if not IsInGuild() then engine=nil; publication=nil; return end
    local guild=GetGuildInfo('player')
    if not guild then return end
    LootBotDB=LootBotDB or {}; LootBotDB.guildStatistics=LootBotDB.guildStatistics or {}
    local key=GetRealmName()..':'..guild
    if engine and engine.key==key then return end
    LootBotDB.guildStatistics[key]=LootBotDB.guildStatistics[key] or {}
    own=canonical(LootBotProtocol.localPlayerName()); joined=false; nextCapture=0
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
            revision=function() return engine.db.revision or 0 end,
            knownRelay=function(name)
                local live=LootBotRelay.Live and LootBotRelay.Live()
                return live and (live:knownRelay(name) or (name==own and live.db.relay)) or false
            end,
            canPublish=function()
                local live=LootBotRelay.Live and LootBotRelay.Live()
                local publisher=engine.db.publication.publisher
                return live and live.db.relay and ((publisher and publisher==own) or (not publisher and live:activeRelay()==own)) or false
            end,
            ready=function() return (engine.db.startedWeek or LootBotGuildStatistics.Week(GetServerTime()))<LootBotGuildStatistics.Week(GetServerTime()) end,
            build=function(printed)
                if LootBotDB.shareStatistics~=false then engine:Capture(LootBotStatisticsProbe.Capture()) end
                return LootBotGuildStatistics.PublicationDraft(engine.db,GetServerTime(),printed,function(name)return roster[canonical(name)]==true end)
            end,
            send=function(message,target)
                if IsInGuild() then LootBotProtocol.sendAddon(paperPrefix,message,target and 'WHISPER' or 'GUILD',target) end
            end,
        })
    end
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
    local printed=latest and latest.edition.readings or {}
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
    nextCapture=0; joined=false
end
for _,event in ipairs({'PLAYER_LOGIN','PLAYER_LOGOUT','CHAT_MSG_ADDON','GUILD_ROSTER_UPDATE','PLAYER_GUILD_UPDATE'}) do driver:RegisterEvent(event) end
driver:SetScript('OnEvent',function(_,event,received,message,channel,sender)
    if event=='PLAYER_LOGOUT' then
        if engine and LootBotDB.shareStatistics~=false then engine:Capture(LootBotStatisticsProbe.Capture()) end
        return
    end
    if event=='CHAT_MSG_ADDON' then
        local name=canonical(sender)
        if name and not roster[name] and C_GuildInfo and C_GuildInfo.MemberExistsByName
            and C_GuildInfo.MemberExistsByName(sender)==true then roster[name]=true end
        if received==prefix and engine and LootBotDB.shareStatistics~=false then engine:Receive(message,canonical(sender),channel) end
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
        if LootBotDB.shareStatistics~=false then engine:Join() end
        if publication then publication:Join() end
    end
    local now=GetServerTime()
    if LootBotDB.shareStatistics~=false and now>=nextCapture then
        nextCapture=now+1800
        engine:Capture(LootBotStatisticsProbe.Capture())
    end
    if LootBotDB.shareStatistics~=false then engine:Tick() end
    if publication then publication:Tick() end
    if LootBotNewsletterPreview and LootBotNewsletterPreview.UpdateBadge then LootBotNewsletterPreview.UpdateBadge() end
end)
