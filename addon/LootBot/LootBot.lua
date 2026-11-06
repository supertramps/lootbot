local P, R = LootBotProtocol, LootBotRelay
local COLS, ROWS, CELL = 128, 16, 1
local marker = CreateFrame('Frame', 'LootBotMarker', UIParent)
local driver = CreateFrame('Frame', 'LootBotDriver', UIParent)
marker:SetFrameStrata('TOOLTIP'); marker:SetFrameLevel(100); marker:EnableMouse(false)
local pixels, templates, members = {}, {}, {}
local whisperNames = {}
local diagnostics = { sent=0, received=0, rejected=0, peers={} }
local relay, db, elapsed, lastPacket, nextRoster, pendingLoot = nil, nil, 0, nil, 0, {}
function LootBotRelay.Live() return relay end
local RARE, EPIC, POLICY_VERSION = 3, 4, 1
local function say(text) print('|cff79d9a6LootBot:|r '..text) end
local function canonical(name) return P.canonical(name,GetRealmName()) end
local function layout()
    local _,height=GetPhysicalScreenSize()
    marker:SetScale((768/height)/UIParent:GetEffectiveScale())
    marker:SetSize(COLS*CELL,ROWS*CELL); marker:ClearAllPoints()
    marker:SetPoint('TOPLEFT',UIParent,'TOPLEFT',16,-16)
end
layout()
local function draw(packet)
    if not packet then marker:Hide(); lastPacket=nil; return end
    if packet==lastPacket then return end
    lastPacket=packet
    if #pixels==0 then
        for i=1,2048 do
            local t=marker:CreateTexture(nil,'OVERLAY'); t:SetSize(CELL,CELL)
            t:SetPoint('TOPLEFT',(i-1)%COLS*CELL,-math.floor((i-1)/COLS)*CELL)
            pixels[i]=t
        end
    end
    for byteIndex=1,256 do
        local value=packet:byte(byteIndex)
        for bitIndex=0,7 do
            local c=math.floor(value/2^(7-bitIndex))%2
            pixels[(byteIndex-1)*8+bitIndex+1]:SetColorTexture(c,c,c,1)
        end
    end
    marker:Show()
end
local function guild()
    local name=GetGuildInfo('player')
    return name and (name..'@'..GetRealmName()) or nil
end
local function roster()
    members={}
    for i=1,GetNumGuildMembers() do
        local name=GetGuildRosterInfo(i)
        if name then members[canonical(name)]=name end
    end
end
local function requestRoster()
    if not IsInGuild() then return end
    if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster()
    elseif GuildRoster then GuildRoster() end
end
local function effectiveQuality()
    return db.epicLocked and EPIC or db.personalQuality
end
local function lockEpic(level)
    if level>=40 and not db.epicLocked then
        db.epicLocked=true; db.personalQuality=EPIC
        if relay then relay:purgeOwnBelow(EPIC) end
        return true
    end
end
local function itemQuality(itemId)
    local info=C_Item and C_Item.GetItemInfo or GetItemInfo
    if info then local _,_,q=info(itemId); return q end
end
local function recordLoot(data)
    local quality=data.quality
    if quality==nil then quality=itemQuality(data.itemId) end
    -- Item information can arrive after the chat line. Hold it briefly rather
    -- than guessing a quality and ever drawing the relay marker for junk.
    if quality==nil then return false end
    local testing=LootBotLocalTestSettings and LootBotLocalTestSettings.allLoot==true or false
    if not testing and (quality<RARE or quality<effectiveQuality()) then return true end
    relay:record({kind='loot',itemId=data.itemId,quality=quality,quantity=data.quantity,itemName=data.itemName,test=testing})
    return true
end
local function loot(message)
    local quantity=P.selfLoot(message,templates)
    if not quantity then return end
    local itemId=tonumber(message:match('|Hitem:(%d+)'))
    if not itemId then return end
    local itemName=message:match('|h%[(.-)%]|h') or ''
    local color=message:match('|c%x%x(%x%x%x%x%x%x)|Hitem:')
    local qualities={['9d9d9d']=0,['ffffff']=1,['1eff00']=2,['0070dd']=3,
        ['a335ee']=4,['ff8000']=5,['e6cc80']=6,['00ccff']=7}
    local quality=color and qualities[color:lower()]
    if not recordLoot({itemId=itemId,quality=quality,quantity=quantity,itemName=itemName}) then
        if #pendingLoot<50 then pendingLoot[#pendingLoot+1]={itemId=itemId,quantity=quantity,itemName=itemName,untilTime=GetTime()+10} end
    end
end
driver:SetScript('OnEvent',function(_,event,...)
    if event=='PLAYER_LOGIN' then
        LootBotDB=LootBotDB or {}
        LootBotDB.characters=LootBotDB.characters or {}
        local guid=UnitGUID('player')
        db=LootBotDB.characters[guid] or {}
        LootBotDB.characters[guid]=db
        if db.policyVersion~=POLICY_VERSION then
            db.policyVersion=POLICY_VERSION; db.personalQuality=RARE
        end
        db.personalQuality=(db.personalQuality==EPIC) and EPIC or RARE
        lockEpic(UnitLevel('player'))
        db.enabled=db.enabled~=false
        relay=R.new(db,{guid=guid,player=canonical(P.localPlayerName()),time=GetTime,now=GetServerTime,
            guild=guild,member=function(name) return members[name]~=nil end,draw=draw,
            send=function(message,target)
                local recipient = target and members[target] and (whisperNames[target] or members[target])
                if target and not recipient then
                    diagnostics.lastSend='No roster address for '..target
                    return
                end
                local channel=target and 'WHISPER' or 'GUILD'
                local result=C_ChatInfo.SendAddonMessage('LootBot2',message,channel,recipient)
                diagnostics.sent=diagnostics.sent+1
                diagnostics.lastSend=channel..' '..(recipient or 'guild')..' result '..tostring(result)
            end})
        -- Clean records from older versions before relay mode can replay them.
        relay:purgeOwnBelow(effectiveQuality())
        for _,key in ipairs({'LOOT_ITEM_SELF_MULTIPLE','LOOT_ITEM_PUSHED_SELF_MULTIPLE','LOOT_ITEM_SELF','LOOT_ITEM_PUSHED_SELF'}) do
            if type(_G[key])=='string' then templates[#templates+1]=_G[key] end
        end
        diagnostics.registration=C_ChatInfo.RegisterAddonMessagePrefix('LootBot2')
        roster(); requestRoster(); layout()
        db.lastLevel=UnitLevel('player')
        if db.relay then relay:syncOptical() end
        say(db.relay and 'Relay enabled. Keep the LootBot tray app running.' or 'Member mode: no marker or desktop app needed. /lootbot help')
    elseif event=='UI_SCALE_CHANGED' or event=='DISPLAY_SIZE_CHANGED' then layout()
    elseif event=='GUILD_ROSTER_UPDATE' then roster()
    elseif event=='PLAYER_GUILD_UPDATE' then roster(); requestRoster()
    elseif relay then
        if event=='PLAYER_LEVEL_UP' then
            local level=...; local locked=lockEpic(level); db.lastLevel=level
            if locked then say('Level 40 reached: blue-drop announcements are now permanently disabled.') end
            if db.enabled then relay:levelUp(level) end
        elseif db.enabled and event=='CHAT_MSG_LOOT' then loot(...)
        elseif db.enabled and event=='CHAT_MSG_ADDON' then
            local prefix,message,channel,sender=...
            if prefix=='LootBot2' then
                local key=canonical(sender)
                -- Forever can format roster and chat names differently. Ask
                -- WoW to verify the original name before trusting a new alias.
                if not members[key] and C_GuildInfo and C_GuildInfo.MemberExistsByName
                    and C_GuildInfo.MemberExistsByName(sender)==true then
                    members[key]=sender
                end
                diagnostics.received=diagnostics.received+1
                diagnostics.lastReceive=channel..' '..sender..' roster='..tostring(members[key]~=nil)
                if not members[key] then diagnostics.rejected=diagnostics.rejected+1 end
                if members[key] then diagnostics.peers[key]=true end
                -- The comparison key strips spaces and may add a realm. Use the
                -- name supplied by WoW for replies, including Forever surnames.
                if members[key] then whisperNames[key]=sender end
                relay:receive(message,channel,key)
            end
        end
    end
end)
driver:SetScript('OnUpdate',function(_,delta)
    if not relay or not db.enabled then return end
    elapsed=elapsed+delta
    if elapsed<0.1 then return end
    elapsed=0; relay:tick()
    for i=#pendingLoot,1,-1 do
        local entry=pendingLoot[i]
        if recordLoot(entry) or GetTime()>=entry.untilTime then table.remove(pendingLoot,i) end
    end
    if GetTime()>nextRoster then nextRoster=GetTime()+60; requestRoster() end
end)
for _,event in ipairs({'PLAYER_LOGIN','CHAT_MSG_LOOT','PLAYER_LEVEL_UP','CHAT_MSG_ADDON',
    'GUILD_ROSTER_UPDATE','PLAYER_GUILD_UPDATE','UI_SCALE_CHANGED','DISPLAY_SIZE_CHANGED'}) do driver:RegisterEvent(event) end
SLASH_LOOTBOT1='/lootbot'
SlashCmdList.LOOTBOT=function(command)
    command=(command or ''):lower():match('^%s*(.-)%s*$')
    if command=='newspaper status' or command=='news status' then
        if LootBotGuildStatistics and LootBotGuildStatistics.PublicationStatus then say(LootBotGuildStatistics.PublicationStatus())
        else say('Restart WoW once to load the newspaper modules.') end
        return
    end
    if command=='newspaper demo' or command=='news demo' then
        if LootBotNewsletterPreview and LootBotNewsletterPreview.ShowDemo then LootBotNewsletterPreview.ShowDemo()
        else say('Restart WoW once to load the newspaper modules.') end
        return
    end
    if command=='stats on' or command=='stats off' then
        if LootBotGuildStatistics and LootBotGuildStatistics.Sharing then
            LootBotGuildStatistics.Sharing(command=='stats on')
            say(command=='stats on' and 'Guild statistics sharing enabled.' or 'Guild statistics sharing paused. Previously shared readings remain with guild members.')
        end
        return
    end
    if command=='stats' then
        if not LootBotStatisticsProbe then say('Restart the beta once to load the new statistics module.'); return end
        local snapshot=LootBotStatisticsProbe.Capture()
        if snapshot.error then say(snapshot.error)
        else say('Read '..#snapshot.entries..' statistics; '..snapshot.populated..' have values. /reload saves this local snapshot for inspection.') end
        return
    end
    if not relay then return end
    if command=='diagnose' then
        local count, peers=0,0
        for _ in pairs(members) do count=count+1 end
        for _ in pairs(diagnostics.peers) do peers=peers+1 end
        say('Diagnostics 1; enabled='..tostring(db.enabled)..'; relay='..tostring(db.relay)..'; guild='..tostring(guild()))
        say('Roster '..count..'; peers heard '..peers..'; prefix result '..tostring(diagnostics.registration))
        say('Sent '..diagnostics.sent..'; received '..diagnostics.received..'; roster rejected '..diagnostics.rejected)
        say('Last send: '..(diagnostics.lastSend or 'none'))
        say('Last receive: '..(diagnostics.lastReceive or 'none'))
        say('Own events '..#db.own..'; received events '..#db.inbox)
    elseif command=='relay on' then db.enabled=true; relay:setRelay(true); say('Relay enabled. Other members have no marker.')
    elseif command=='relay off' then relay:setRelay(false); say('Member mode enabled; marker hidden.')
    elseif command=='sync' then relay:syncOptical(); relay.lastHello=-100; say('Saved records queued for replay; the shared service prevents duplicate posts.')
    elseif command=='test' then
        relay:record({kind='loot',itemId=19019,quality=5,quantity=1,itemName='LootBot test item',test=true})
        say('Labeled test loot recorded. Relay mode must be on at the host.')
    elseif command=='test level' then
        relay:record({kind='level',level=10,test=true}); say('Labeled test level recorded.')
    elseif command=='test backlog' then
        relay:record({kind='loot',itemId=755,quality=4,quantity=1,itemName='Catch-up test item',test=true,timestamp=GetServerTime()-86400})
        say('Labeled one-day-old test recorded; it belongs in the catch-up digest.')
    elseif command=='newspaper' or command=='news' then
        if LootBotNewsletterPreview and type(LootBotNewsletterPreview.Show)=='function' then
            LootBotNewsletterPreview.Show()
        else
            say('Newspaper preview could not load. Loot tracking is unaffected.')
        end
    elseif command=='off' then db.enabled=false; draw(nil); say('Recording and syncing paused.')
    elseif command=='on' then db.enabled=true; say('Resumed.')
    elseif command=='filter' then
        say('Personal loot filter: '..(effectiveQuality()==EPIC and 'Epic and above' or 'Rare and above')..(db.epicLocked and ' (locked at level 40).' or '.'))
    elseif command=='filter epic' then
        db.personalQuality=EPIC; relay:purgeOwnBelow(EPIC); say('Personal loot filter: Epic and above.')
    elseif command=='filter rare' then
        if db.epicLocked then say('Blue-drop announcements end at level 40. Your filter is Epic and above.')
        else db.personalQuality=RARE; say('Personal loot filter: Rare and above.') end
    elseif command=='version' then
        local version,build,_,interface=GetBuildInfo(); say('LootBot 0.4.1; client '..version..', build '..build..', interface '..interface)
    else
        say('relay on/off | sync | test | test level | test backlog | newspaper | stats | filter [rare|epic] | on/off.')
        say('Mode: '..(db.relay and 'relay' or 'member')..'; saved own events: '..#db.own..'; synced events: '..#db.inbox)
    end
end
marker:Hide()
