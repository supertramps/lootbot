-- Guild-only transport. Never touches the optical marker or cloud relay.
local prefix='LootBotNews1'
local driver=CreateFrame('Frame','LootBotStatisticsDriver')
local elapsed,nextCapture,joined=0,0,false
local engine,roster,own=nil, {}, nil
local function canonical(name)
    if not name then return nil end
    if not name:find('-',1,true) then name=name..'-'..GetRealmName():gsub('%s','') end
    return name
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
    if not IsInGuild() then engine=nil; return end
    local guild=GetGuildInfo('player')
    if not guild then return end
    LootBotDB=LootBotDB or {}; LootBotDB.guildStatistics=LootBotDB.guildStatistics or {}
    local key=GetRealmName()..':'..guild
    if engine and engine.key==key then return end
    LootBotDB.guildStatistics[key]=LootBotDB.guildStatistics[key] or {}
    own=canonical(UnitName('player')); joined=false; nextCapture=0
    engine=LootBotGuildStatistics.New(LootBotDB.guildStatistics[key],{
        now=GetServerTime,player=function() return own end,
        member=function(name) return roster[canonical(name)]==true end,
        send=function(message,target)
            if LootBotDB.shareStatistics==false or not IsInGuild() then return end
            C_ChatInfo.SendAddonMessage(prefix,message,target and 'WHISPER' or 'GUILD',target)
        end
    })
    engine.key=key
end
function LootBotGuildStatistics.CurrentEdition()
    return engine and engine.db and LootBotGuildStatistics.Edition(engine.db,GetServerTime()) or LootBotGuildStatistics.Launch(GetServerTime())
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
        if received==prefix and engine and LootBotDB.shareStatistics~=false then engine:Receive(message,canonical(sender),channel) end
    else
        if event=='PLAYER_LOGIN' then
            C_ChatInfo.RegisterAddonMessagePrefix(prefix)
            if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
        end
        members(); initialise()
    end
end)
driver:SetScript('OnUpdate',function(_,delta)
    elapsed=elapsed+delta
    if elapsed<0.5 then return end
    elapsed=0
    if not engine or not engine.db or not roster[own] or LootBotDB.shareStatistics==false then return end
    if not joined then joined=true; engine:Join() end
    local now=GetServerTime()
    if now>=nextCapture then
        nextCapture=now+1800
        engine:Capture(LootBotStatisticsProbe.Capture())
    end
    engine:Tick()
    if LootBotNewsletterPreview and LootBotNewsletterPreview.UpdateBadge then LootBotNewsletterPreview.UpdateBadge() end
end)
