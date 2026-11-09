-- Fresh, guild-wide celebrations. Deliberately independent of saved relay history.
LootBotLevelToast = {}
local T, P = LootBotLevelToast, LootBotProtocol
local PREFIX, MAX_AGE = 'LootBotDing1', 20
local driver = CreateFrame('Frame', 'LootBotDingDriver', UIParent)
local db, settings, frame, queue, active, roster = nil, nil, nil, {}, nil, {}
local ROOT = 'Interface\\AddOns\\LootBot\\'
local function volume(value)
    if type(value)~='number' or value~=value then return 50 end
    return math.max(0,math.min(100,math.floor(value/10+.5)*10))
end
function T.PlayPingSound(preview)
    if not settings or (not preview and not settings.sound) or not PlaySoundFile then return end
    if T.soundHandle and StopSound then StopSound(T.soundHandle,100); T.soundHandle=nil end
    local amount=volume(settings.volume)
    if amount==0 then return end
    local _,handle=PlaySoundFile(ROOT..'Sounds\\Victory-'..amount..'.ogg','SFX')
    T.soundHandle=handle
end
local function allowed(item) return settings.enabled and settings[item.kind or 'level']~=false end
local function enabled() return db and db.enabled~=false end
local function validLevel(n) return type(n)=='number' and n>=10 and n<=60 and n%10==0 end
local function flair(item)
    if item.kind=='item' then
        return item.quality==5 and {1,.67,.18,.8,.34} or {.7,.38,.94,.45,.2}
    elseif item.kind=='mount' then return {.48,.72,.42,.4,.16} end
    local tier=(item.level or 10)/10
    return {1,.68+tier*.025,.26,.12+tier*.12,.07+tier*.025}
end
local function key(name) return P.canonical(name, GetRealmName()) end
local function refreshRoster()
    roster={}
    for i=1,GetNumGuildMembers() do
        local name=GetGuildRosterInfo(i)
        if name then roster[key(name)]=true end
    end
end
local function guildMember(name)
    return roster[key(name)] or (C_GuildInfo and C_GuildInfo.MemberExistsByName
        and C_GuildInfo.MemberExistsByName(name)==true)
end
local function label(parent, size, x, y, width)
    local text=parent:CreateFontString(nil,'OVERLAY')
    text:SetFont(STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF',size)
    text:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y)
    text:SetSize(width,22); text:SetJustifyH('LEFT'); text:SetTextColor(.19,.12,.06)
    return text
end
local function applyPosition(target)
    target:ClearAllPoints()
    local pos=settings.position
    if type(pos)=='table' and type(pos.x)=='number' and type(pos.y)=='number' then
        target:SetPoint('CENTER',UIParent,'BOTTOMLEFT',
            math.max(195,math.min(UIParent:GetWidth()-195,pos.x*UIParent:GetWidth())),
            math.max(65,math.min(UIParent:GetHeight()-65,pos.y*UIParent:GetHeight())))
    else target:SetPoint('TOP',UIParent,'TOP',0,-100) end
end
local function build()
    if frame then return end
    frame=CreateFrame('Frame','LootBotLevelToastFrame',UIParent)
    frame:SetSize(390,130); frame:SetPoint('TOP',UIParent,'TOP',0,-100)
    frame:SetFrameStrata('HIGH'); frame:EnableMouse(false)
    frame.paper=frame:CreateTexture(nil,'BACKGROUND')
    frame.paper:SetTexture(ROOT..'PeonToast.tga')
    frame.paper:SetPoint('TOPLEFT',frame,'TOPLEFT',105.3,0)
    -- Mirror the torn right edge for a matching left edge behind loot portraits.
    frame.paperEdge=frame:CreateTexture(nil,'BACKGROUND')
    frame.paperEdge:SetTexture(ROOT..'PeonToast.tga')
    frame.paperEdge:SetPoint('TOPLEFT',frame,'TOPLEFT',14,0)
    frame.paperEdge:SetSize(91.3,130)
    frame.paperEdge:SetTexCoord(1,1-91.3/390,0,1)
    frame.portrait=frame:CreateTexture(nil,'ARTWORK')
    frame.portrait:SetTexture(ROOT..'PeonToast.tga')
    frame.portrait:SetTexCoord(0,.27,0,1)
    frame.portrait:SetPoint('TOPLEFT',frame,'TOPLEFT',0,0); frame.portrait:SetSize(105.3,130)
    -- Item and mount portraits share the parchment's bronze visual language.
    frame.icon=frame:CreateTexture(nil,'ARTWORK',nil,1); frame.icon:SetSize(90,90)
    frame.icon:SetPoint('CENTER',frame,'TOPLEFT',54,-65)
    frame.icon:SetTexCoord(.07,.93,.07,.93)
    frame.iconMask=frame:CreateMaskTexture()
    frame.iconMask:SetTexture('Interface\\CharacterFrame\\TempPortraitAlphaMask')
    frame.iconMask:SetAllPoints(frame.icon); frame.icon:AddMaskTexture(frame.iconMask)
    frame.iconBorder=frame:CreateTexture(nil,'OVERLAY',nil,0)
    frame.iconBorder:SetTexture(ROOT..'PingPortraitRing.tga')
    frame.iconBorder:SetSize(106,106); frame.iconBorder:SetPoint('CENTER',frame,'TOPLEFT',54,-65)
    frame.words=CreateFrame('Frame',nil,frame); frame.words:SetAllPoints(frame); frame.words:EnableMouse(false)
    frame.name=label(frame.words,16,113,-39,220)
    frame.message=label(frame.words,14,113,-62,220)
    frame.extra=label(frame.words,11,113,-85,258)
    frame.extra:SetSize(258,30); frame.extra:SetJustifyV('TOP')
    frame.accent=frame.words:CreateTexture(nil,'BACKGROUND')
    frame.accent:SetPoint('TOPLEFT',frame.words,'TOPLEFT',113,-33); frame.accent:SetSize(220,1)
    frame.seal=CreateFrame('Frame',nil,frame); frame.seal:SetSize(40,40)
    frame.seal:SetPoint('CENTER',frame,'TOPLEFT',354,-61); frame.seal:EnableMouse(false)
    -- Scale a centered child, never the offset anchor: scaling the anchor causes drift.
    frame.stamp=CreateFrame('Frame',nil,frame.seal); frame.stamp:SetSize(40,40)
    frame.stamp:SetPoint('CENTER',frame.seal,'CENTER',0,0); frame.stamp:EnableMouse(false)
    local seal=frame.stamp:CreateTexture(nil,'BACKGROUND'); seal:SetAllPoints(frame.stamp)
    seal:SetTexture(ROOT..'DingSeal.tga')
    frame.number=frame.stamp:CreateFontString(nil,'OVERLAY')
    frame.number:SetFont(STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF',16)
    frame.number:SetPoint('CENTER',frame.stamp,'CENTER',0,0); frame.number:SetTextColor(.96,.82,.55)
    frame.shine=frame:CreateTexture(nil,'OVERLAY'); frame.shine:SetTexture('Interface\\Cooldown\\star4')
    frame.shine:SetSize(40,40); frame.shine:SetBlendMode('ADD'); frame.shine:SetVertexColor(1,.78,.35)
    frame.embers={}
    for i=1,28 do
        local ember=frame:CreateTexture(nil,'OVERLAY')
        ember:SetTexture('Interface\\Cooldown\\star4'); ember:SetBlendMode('ADD')
        ember:SetSize(3+i%5,3+i%5); ember:SetVertexColor(1,.25+(i%3)*.12,.035)
        ember:Hide(); frame.embers[i]=ember
    end
    -- The toast is click-through; use the command to disable it, no obstructing close button.
    frame:Hide()
end
local function animate(t)
    local motion=settings.animation
    local reveal=motion and math.min(1,t/.3) or 1
    reveal=1-(1-reveal)^3
    local fadeIn=math.sin(math.min(1,t/.2)*math.pi/2)
    local fadeOut=math.sin(math.min(1,math.max(0,(active.duration-t)/.3))*math.pi/2)
    frame:SetAlpha(motion and math.min(fadeIn,fadeOut) or 1)
    frame.paper:SetSize(math.max(.01,284.7*reveal),130)
    frame.paper:SetTexCoord(.27,.27+.73*math.max(.0001,reveal),0,1)
    frame.words:SetAlpha(motion and math.min(1,math.max(0,(t-.15)/.15)) or 1)
    local stampAge=t-.32
    local stampScale,stampY,stampAlpha=1,0,1
    if motion and stampAge<0 then
        stampAlpha=0
    elseif motion and stampAge<.16 then
        -- Accelerate into the paper, then settle once instead of wobbling.
        local progress=stampAge/.16
        stampScale=1.28-.32*progress*progress
        stampY=10-11*progress*progress
        stampAlpha=math.min(1,stampAge/.045)
    elseif motion and stampAge<.30 then
        local settle=1-(1-(stampAge-.16)/.14)^3
        stampScale=.96+.04*settle; stampY=-1+settle
    end
    frame.seal:SetAlpha(active.kind=='level' and stampAlpha or 0)
    frame.stamp:SetScale(stampScale)
    frame.stamp:ClearAllPoints(); frame.stamp:SetPoint('CENTER',frame.seal,'CENTER',0,stampY)
    frame.shine:Hide()
    local sweep=active.flair[4]
    if motion and (active.kind~='level' or active.level>=30) and t>.5 and t<.5+sweep then
        local progress=(t-.5)/sweep
        frame.shine:ClearAllPoints(); frame.shine:SetPoint('CENTER',frame,'TOPLEFT',115+210*progress,-53)
        frame.shine:SetAlpha(active.flair[5]*1.5*math.sin(progress*math.pi)); frame.shine:Show()
    end
    -- Reused textures animate only while the max-level toast is visible.
    for i,ember in ipairs(frame.embers) do
        local age=(t-.2-(i-1)*.075)%2.8
        if motion and active.level==60 and t>.2+(i-1)*.075 and t<active.duration-.4 then
            local rise=age/2.8
            local x=85+(i*37)%290+math.sin(age*2+i)*11
            ember:ClearAllPoints(); ember:SetPoint('CENTER',frame,'TOPLEFT',x,-110+rise*145)
            ember:SetAlpha(.9*math.sin(math.pi*rise)); ember:Show()
        else ember:Hide() end
    end
end
local function startNext()
    while #queue>0 do
        local item=table.remove(queue,1)
        if item.expires>=GetTime() and (item.preview or (enabled() and allowed(item))) then
            build(); applyPosition(frame); active=item; active.started=GetTime(); active.duration=item.level==60 and 6 or 4
            active.flair=flair(item)
            local color=active.flair
            frame.accent:SetColorTexture(color[1]*.55,color[2]*.55,color[3]*.55,.8)
            frame.shine:SetVertexColor(color[1],color[2],color[3])
            -- Keep the bronze rim natural; rarity is carried by the rule and item name.
            frame.extra:SetTextColor(item.kind=='item' and color[1]*.45 or .19,
                item.kind=='item' and color[2]*.45 or .12,item.kind=='item' and color[3]*.45 or .06)
            frame.name:SetText(item.name)
            if item.kind=='level' then
                frame.message:SetText('reached level '..item.level..'!'); frame.number:SetText(tostring(item.level))
                frame.portrait:Show(); frame.paperEdge:Hide(); frame.icon:Hide(); frame.iconBorder:Hide()
            else
                local rarity=({[4]='an epic',[5]='a legendary',[6]='an artifact',[7]='an heirloom'})[item.quality] or 'an epic'
                frame.message:SetText(item.kind=='item' and ('looted '..rarity..'!') or 'got their first mount!')
                frame.portrait:Hide(); frame.paperEdge:Show(); frame.icon:Show(); frame.iconBorder:Show()
                frame.icon:SetTexture(item.icon or 134400)
            end
            -- Reserve a third line only for the max-level joke; keep the seal clear of it.
            frame.extra:SetText(item.kind=='level' and (item.level==60 and "Maybe it's time to touch some grass?" or '') or (item.detail or ''))
            frame:Show(); animate(0)
            T.PlayPingSound(false)
            frame:SetScript('OnUpdate',function()
                local t=GetTime()-active.started
                if t>=active.duration then
                    frame:Hide(); frame:SetScript('OnUpdate',nil); active=nil; startNext()
                else animate(t) end
            end)
            return
        end
    end
end
local function enqueue(name,level,preview,details)
    local item=details or {kind='level'}
    if (not preview and not allowed(item)) or #queue>=5 then return end
    item.name=name:match('^([^-]+)') or name; item.level=level; item.preview=preview; item.expires=GetTime()+MAX_AGE
    queue[#queue+1]=item
    if not active then startNext() end
end
local function stop()
    queue={}; active=nil
    if T.soundHandle and StopSound then StopSound(T.soundHandle,100); T.soundHandle=nil end
    if frame then frame:Hide(); frame:SetScript('OnUpdate',nil) end
end
local options, mover
function T.MovePings()
    if not settings then return end
    stop()
    if options then options:Hide() end
    if not mover then
        mover=CreateFrame('Frame','LootBotPingMover',UIParent,'BackdropTemplate')
        mover:SetSize(390,130); mover:SetFrameStrata('DIALOG')
        mover:SetMovable(true); mover:SetClampedToScreen(true); mover:EnableMouse(true); mover:RegisterForDrag('LeftButton')
        mover:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=14})
        mover:SetBackdropColor(.12,.09,.06,.95)
        local title=label(mover,16,24,-25,342); title:SetTextColor(1,.82,.45); title:SetText('Drag to move your pings')
        local hint=label(mover,12,24,-52,342); hint:SetTextColor(.95,.89,.77); hint:SetText('All future pings will appear here.')
        mover:SetScript('OnDragStart',function(self) self:StartMoving() end)
        mover:SetScript('OnDragStop',function(self)
            self:StopMovingOrSizing()
            local x,y=self:GetCenter()
            settings.position={x=x/UIParent:GetWidth(),y=y/UIParent:GetHeight()}
            applyPosition(self)
        end)
        local done=CreateFrame('Button',nil,mover,'UIPanelButtonTemplate')
        done:SetSize(120,26); done:SetPoint('BOTTOM',mover,'BOTTOM',0,12); done:SetText('Done')
        done:SetScript('OnClick',function() mover:Hide(); T.Options() end)
        UISpecialFrames[#UISpecialFrames+1]='LootBotPingMover'
    end
    applyPosition(mover); mover:Show()
end
function T.Options()
    if not settings then return end
    if not options then
        options=CreateFrame('Frame','LootBotPopupOptions',UIParent,'BackdropTemplate')
        options:SetSize(380,640); options:SetPoint('CENTER',UIParent,'CENTER',0,0)
        options:SetFrameStrata('DIALOG'); options:EnableMouse(true)
        options:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',
            edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,
            insets={left=6,right=6,top=6,bottom=6}})
        local title=label(options,20,24,-24,330); title:SetTextColor(1,.82,.45); title:SetText('LootBot pings')
        local note=label(options,12,24,-52,330); note:SetTextColor(.85,.81,.72); note:SetText('Your screen and sound preferences')
        options.checks={}
        local choices={{'enabled','Enable all pings'},{'level','Level pings'},{'item','Epic loot pings'},{'mount','First-mount pings'},
            {'sound','Play ping sounds'},{'animation','Animate pings'}}
        for i,entry in ipairs(choices) do
            local field=entry[1]
            local box=CreateFrame('CheckButton',nil,options,'UICheckButtonTemplate')
            box:SetSize(26,26); box:SetPoint('TOPLEFT',options,'TOPLEFT',24,-78-(i-1)*35)
            local text=label(options,14,57,-82-(i-1)*35,294); text:SetTextColor(.94,.89,.78); text:SetText(entry[2])
            box:SetScript('OnClick',function(self)
                settings[field]=self:GetChecked()==true
                if field=='enabled' and not settings.enabled then stop() end
                if active and active.kind==field and not settings[field] then stop() end
                if field=='sound' and not settings.sound and T.soundHandle and StopSound then
                    StopSound(T.soundHandle,100); T.soundHandle=nil
                end
            end)
            options.checks[field]=box
        end
        local function button(text,x,y,width,callback)
            local b=CreateFrame('Button',nil,options,'UIPanelButtonTemplate')
            b:SetSize(width,26); b:SetPoint('TOPLEFT',options,'TOPLEFT',x,y); b:SetText(text); b:SetScript('OnClick',callback)
            return b
        end
        local volumeText=label(options,12,24,-291,220); volumeText:SetTextColor(.94,.89,.78)
        local slider=CreateFrame('Slider','LootBotPingVolumeSlider',options,'OptionsSliderTemplate')
        slider:SetSize(210,18); slider:SetPoint('TOPLEFT',options,'TOPLEFT',28,-318)
        slider:SetMinMaxValues(0,100); slider:SetValueStep(10); slider:SetObeyStepOnDrag(true)
        if slider.Low then slider.Low:SetText('0%') end
        if slider.High then slider.High:SetText('100%') end
        if slider.Text then slider.Text:SetText('') end
        slider:SetScript('OnValueChanged',function(_,value)
            settings.volume=volume(value); volumeText:SetText('Ping volume: '..settings.volume..'%')
            if T.soundHandle and StopSound then StopSound(T.soundHandle,100); T.soundHandle=nil end
        end)
        options.volume=slider
        button('Test sound',254,-311,102,function() T.PlayPingSound(true) end)
        options.testLevel=40
        local menu=CreateFrame('Frame',nil,options,'BackdropTemplate')
        menu:SetSize(158,166); menu:SetFrameStrata('TOOLTIP'); menu:EnableMouse(true)
        menu:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12})
        local dropdown=button('Level 40  v',24,-375,158,function() if menu:IsShown() then menu:Hide() else menu:Show() end end)
        menu:SetPoint('TOPLEFT',dropdown,'BOTTOMLEFT',0,-2)
        for _,value in ipairs({10,20,30,40,50,60}) do
            local choice=value
            local b=CreateFrame('Button',nil,menu,'UIPanelButtonTemplate')
            b:SetSize(146,24); b:SetPoint('TOPLEFT',menu,'TOPLEFT',6,-6-(choice/10-1)*26); b:SetText('Level '..choice)
            b:SetScript('OnClick',function() options.testLevel=choice; dropdown:SetText('Level '..choice..'  v'); menu:Hide() end)
        end
        menu:Hide(); options:SetScript('OnHide',function() menu:Hide() end)
        button('Preview level',198,-375,158,function() menu:Hide(); stop(); enqueue('LootTester',options.testLevel,true) end)
        button('Epic loot',24,-412,102,function() menu:Hide(); stop(); T.PreviewItem() end)
        button('Legendary loot',139,-412,102,function() menu:Hide(); stop(); T.PreviewLegendary() end)
        button('First mount',254,-412,102,function() menu:Hide(); stop(); T.PreviewMount() end)
        local hint=label(options,11,24,-449,330); hint:SetTextColor(.75,.73,.68); hint:SetText('Dummy previews stay local, even with pings off.')
        button('Move pings',24,-481,158,T.MovePings)
        button('Reset position',198,-481,158,function()
            settings.position=nil
            if frame then applyPosition(frame) end
            if mover then applyPosition(mover) end
        end)
        local newsLabel=label(options,12,24,-521,330); newsLabel:SetTextColor(.94,.89,.78)
        newsLabel:SetText('OF-Posten — provnummer med statistik')
        button('Visa provtidning',24,-548,332,function()
            options:Hide()
            if LootBotNewsletterPreview then LootBotNewsletterPreview.ShowDemo('WoW') end
        end)
        button('Close',132,-596,116,function() options:Hide() end)
        UISpecialFrames[#UISpecialFrames+1]='LootBotPopupOptions'
    end
    for field,box in pairs(options.checks) do box:SetChecked(settings[field]) end
    options.volume:SetValue(volume(settings.volume))
    options:Show()
end
function T.Receive(message,channel,sender)
    if not enabled() or channel~='GUILD' or type(sender)~='string' or type(message)~='string' then return end
    if issecretvalue and (issecretvalue(message) or issecretvalue(sender)) then return end
    if not IsInGuild() or not guildMember(sender) or key(sender)==key(P.localPlayerName()) then return end
    if message:sub(1,3)=='I1:' or message:sub(1,3)=='M1:' then T.ReceiveExtra(message,sender); return end
    local level,stamp=message:match('^D1:(%d+):(%d+)$')
    level,stamp=tonumber(level),tonumber(stamp)
    if not validLevel(level) or not stamp or GetServerTime()-stamp>MAX_AGE or stamp-GetServerTime()>5 then return end
    local id=key(sender)..':'..level
    if settings.seen[id] then return end
    settings.seen[id]=GetServerTime(); enqueue(sender,level)
end
function T.LevelUp(level)
    if not enabled() or not validLevel(level) then return end
    local id=UnitGUID('player')..':'..level
    if settings.seen[id] then return end
    settings.seen[id]=GetServerTime()
    enqueue(P.localPlayerName(),level)
    if IsInGuild() then P.sendAddon(PREFIX,'D1:'..level..':'..GetServerTime(),'GUILD') end
end
local function itemDetails(id,quality)
    local info=C_Item and C_Item.GetItemInfo or GetItemInfo
    local name,_,actualQuality,_,_,_,_,_,_,icon
    if info then name,_,actualQuality,_,_,_,_,_,_,icon=info(id) end
    local iconAPI=C_Item and C_Item.GetItemIconByID or GetItemIcon
    icon=icon or (iconAPI and iconAPI(id))
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    return {kind='item',itemId=id,quality=actualQuality or quality,detail=name or 'Epic loot',icon=icon or 134400}
end
function T.RefreshItem(id,success)
    if not success then return end
    for _,item in ipairs(queue) do
        if item.kind=='item' and item.itemId==id then
            local data=itemDetails(id,item.quality); item.detail=data.detail; item.icon=data.icon
        end
    end
    if active and active.kind=='item' and active.itemId==id then
        local data=itemDetails(id,active.quality); active.detail=data.detail; active.icon=data.icon
        frame.extra:SetText(data.detail); frame.icon:SetTexture(data.icon)
    end
end
function T.Loot(event)
    if not enabled() or not event or event.test or event.quality<4 or event.quality>7 then return end
    settings.counter=(settings.counter or 0)+1
    local data=itemDetails(event.itemId,event.quality)
    enqueue(P.localPlayerName(),nil,false,data)
    if IsInGuild() then
        P.sendAddon(PREFIX,table.concat({'I1',event.itemId,event.quality,GetServerTime(),settings.counter},':'),'GUILD')
    end
end
local function mountInfo(id)
    if C_MountJournal and C_MountJournal.GetMountInfoByID then
        return C_MountJournal.GetMountInfoByID(id)
    end
end
local function mountCount()
    if not C_MountJournal or not C_MountJournal.GetMountIDs or not C_MountJournal.GetMountInfoByID then return end
    local ids=C_MountJournal.GetMountIDs()
    if type(ids)~='table' or #ids==0 then return end -- unavailable is not zero ownership
    local count=0
    for _,id in ipairs(ids) do
        local name,_,_,_,_,_,_,_,_,_,collected=mountInfo(id)
        if not name then return end
        if collected then count=count+1 end
    end
    return count
end
function T.MountBaseline()
    if not settings then return end
    local count=mountCount()
    settings.mountBaselineKnown=count~=nil
    if count and count>0 then settings.mountEverOwned=true end
end
function T.NewMount(id)
    if not settings or settings.mountEverOwned then return end
    local count=mountCount()
    local name,_,icon,_,_,_,_,_,_,_,collected=mountInfo(id)
    if not count or not collected then return end
    local first=settings.mountBaselineKnown and count==1
    settings.mountEverOwned=true
    if not first or not enabled() then return end
    enqueue(P.localPlayerName(),nil,false,{kind='mount',detail=name,icon=icon})
    if IsInGuild() then P.sendAddon(PREFIX,'M1:'..id..':'..GetServerTime(),'GUILD') end
end
function T.ReceiveExtra(message,sender)
    local id,quality,stamp,sequence=message:match('^I1:(%d+):(%d+):(%d+):(%d+)$')
    local kind='item'
    if not id then id,stamp=message:match('^M1:(%d+):(%d+)$'); kind='mount' end
    id,stamp,quality=tonumber(id),tonumber(stamp),tonumber(quality)
    if not id or id<1 or id>10000000 or not stamp or GetServerTime()-stamp>MAX_AGE or stamp-GetServerTime()>5 then return end
    if kind=='item' and (not quality or quality<4 or quality>7) then return end
    local identity=kind=='mount' and (key(sender)..':first-mount') or (key(sender)..':'..message)
    if settings.seen[identity] then return end
    settings.seen[identity]=GetServerTime()
    local details
    if kind=='item' then details=itemDetails(id,quality)
    else
        local name,_,icon=mountInfo(id)
        details={kind='mount',detail=name or 'A new travelling companion',icon=icon or 'Interface\\Icons\\Ability_Mount_RidingHorse'}
    end
    enqueue(sender,nil,false,details)
end
function T.PreviewItem()
    -- Use a familiar epic weapon for the ordinary loot example.
    local data=itemDetails(19364,4)
    if data.detail=='Epic loot' then data.detail='Ashkandi, Greatsword of the Brotherhood'; data.icon='Interface\\Icons\\INV_Sword_50' end
    enqueue('LootTester',nil,true,data)
end
function T.PreviewMount()
    enqueue('LootTester',nil,true,{kind='mount',detail='Brown Wolf',icon='Interface\\Icons\\Ability_Mount_BlackDireWolf'})
end
function T.PreviewLegendary()
    local data=itemDetails(19019,5)
    if data.detail=='Epic loot' then
        data.detail='Thunderfury, Blessed Blade of the Windseeker'; data.icon='Interface\\Icons\\INV_Sword_39'
    end
    enqueue('LootTester',nil,true,data)
end
function T.Command(command)
    if command=='options' then T.Options(); return true end
    if command~='popup' and command:sub(1,6)~='popup ' then return false end
    if not settings then return true end
    local level=command:match('^popup test (%d+)$')
    if command=='popup test' then level='40' end
    if level then
        level=tonumber(level)
        if validLevel(level) then stop(); enqueue('LootTester',level,true)
        else print('LootBot: Choose 10, 20, 30, 40, 50 or 60.') end
    elseif command=='popup on' or command=='popup off' then
        settings.enabled=command=='popup on'
        if not settings.enabled then
            stop()
        end
        print('LootBot: Popups '..(settings.enabled and 'on.' or 'off.'))
    elseif command=='popup sound on' or command=='popup sound off' then
        settings.sound=command=='popup sound on'; print('LootBot: Popup sound '..(settings.sound and 'on.' or 'off.'))
    elseif command=='popup animation on' or command=='popup animation off' then
        settings.animation=command=='popup animation on'; print('LootBot: Popup animation '..(settings.animation and 'on.' or 'off.'))
    else
        print('LootBot: popup test [40/60] | popup on/off | popup sound on/off | popup animation on/off')
        print('LootBot: Popups '..(settings.enabled and 'on' or 'off')..'; sound '..(settings.sound and 'on' or 'off')..'; animation '..(settings.animation and 'on' or 'off'))
    end
    return true
end
driver:SetScript('OnEvent',function(_,event,...)
    if event=='PLAYER_LOGIN' then
        LootBotDB=LootBotDB or {}; LootBotDB.characters=LootBotDB.characters or {}
        local guid=UnitGUID('player')
        LootBotDB.characters[guid]=LootBotDB.characters[guid] or {}; db=LootBotDB.characters[guid]
        db.popups=db.popups or {}; settings=db.popups
        settings.enabled=settings.enabled~=false; settings.animation=settings.animation~=false
        settings.level=settings.level~=false; settings.item=settings.item~=false; settings.mount=settings.mount~=false
        settings.sound=settings.sound==true -- quiet by default; preview uses the same preference
        settings.volume=volume(settings.volume)
        settings.seen=settings.seen or {}
        for id,stamp in pairs(settings.seen) do
            if type(stamp)~='number' or GetServerTime()-stamp>30*86400 then settings.seen[id]=nil end
        end
        refreshRoster(); C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        T.MountBaseline()
    elseif event=='GUILD_ROSTER_UPDATE' or event=='PLAYER_GUILD_UPDATE' then refreshRoster()
    elseif event=='PLAYER_LEVEL_UP' then T.LevelUp(...)
    elseif event=='NEW_MOUNT_ADDED' then T.NewMount(...)
    elseif event=='GET_ITEM_INFO_RECEIVED' then T.RefreshItem(...)
    elseif event=='CHAT_MSG_ADDON' then
        local prefix,message,channel,sender=...
        if prefix==PREFIX then T.Receive(message,channel,sender) end
    end
end)
for _,event in ipairs({'PLAYER_LOGIN','PLAYER_LEVEL_UP','CHAT_MSG_ADDON','GUILD_ROSTER_UPDATE','PLAYER_GUILD_UPDATE'}) do
    driver:RegisterEvent(event)
end
driver:RegisterEvent('GET_ITEM_INFO_RECEIVED')
-- Era clients without a mount journal must still load the rest of LootBot.
if C_MountJournal and C_MountJournal.GetMountIDs then driver:RegisterEvent('NEW_MOUNT_ADDED') end
