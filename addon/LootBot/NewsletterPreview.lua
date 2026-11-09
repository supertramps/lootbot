-- Borderless weekly paper and separate first-week welcome cover.
LootBotNewsletterPreview = {}
local News = LootBotNewsletterPreview

local PAGE_W, PAGE_H = 1086, 1448
local NAV_HEIGHT, NAV_GAP = 28, 5
local function fittedWidth()
    local availableHeight=UIParent:GetHeight()*.97-NAV_HEIGHT-NAV_GAP
    return math.min(availableHeight*PAGE_W/PAGE_H,UIParent:GetWidth()*.95)
end
local fitWidth = fittedWidth()
local pageWidth = fitWidth
local MIN_WIDTH, MAX_WIDTH = fitWidth, fitWidth*2.5
local ink = {0.19, 0.13, 0.09}
local accent = {0.38, 0.12, 0.10}
local slots = {
    {key='masthead', x=260,y=100,w=566,h=135,size=55,center=true,display='THE GUILD GAZETTE'},
    {key='edition', x=64,y=283,w=958,h=29,size=19,center=true,display='SAMPLE ISSUE  |  WEEK OF 1 OCTOBER  |  ALL FIGURES ARE MADE UP'},
    {key='headline', x=66,y=351,w=954,h=104,size=48,center=true,display='Twenty heroes. One very busy graveyard.'},
    {key='lead', x=58,y=515,w=548,h=369,size=28,display='The guild had a week to remember. Some of us would rather forget the walk back to our corpses.\n\nGruk led the death count with 18. Mara brought home the most epic loot. Nim caught 98 fish and insists this counts as progress.\n\nSee the numbers below. The names are fake; the newspaper is a preview.'},
    {key='leftTitle', x=52,y=957,w=282,h=42,size=29,center=true,display='DEATH TOLL'},
    {key='leftBody', x=52,y=1007,w=282,h=238,size=25,display='DEATHS THIS WEEK\n\n1  Gruk ............ 18\n2  Nim ............. 12\n3  Mara ............. 7\n\nFalling claimed 9.'},
    {key='middleTitle', x=388,y=957,w=314,h=42,size=29,center=true,display='SPOILS OF WAR'},
    {key='middleBody', x=388,y=1007,w=314,h=238,size=25,display='EPICS LOOTED\n\n1  Mara ............. 4\n2  Tusk ............. 3\n3  Gruk ............. 2\n\nGuild total: 14'},
    {key='rightTitle', x=746,y=957,w=282,h=42,size=29,center=true,display='ODDS & ENDS'},
    {key='rightBody', x=746,y=1007,w=282,h=238,size=25,display='CRITTERS SLAIN  312\nFISH CAUGHT ..... 98\nWAVES GIVEN .... 217\nBOSSES DOWN ..... 42\n\nNext week: less lava.'},
}

local frame = CreateFrame('Frame','LootBotNewsletterFrame',UIParent)
-- Hide immediately. If any later setup fails, never leave a partial window
-- covering the game UI.
frame:Hide()
frame:SetSize(fitWidth,fitWidth*PAGE_H/PAGE_W)
frame:SetPoint('CENTER')
frame:SetFrameStrata('DIALOG')
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag('LeftButton')
frame:SetScript('OnDragStart',function(self) self:StartMoving() end)
frame:SetScript('OnDragStop',function(self) self:StopMovingOrSizing() end)
local close=CreateFrame('Button','LootBotNewsletterCloseButton',frame)
close:SetSize(24,24)
close:SetPoint('TOPRIGHT',frame,'TOPRIGHT',-8,-8)
close:SetFrameLevel(200)
local closeText=close:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
closeText:SetPoint('CENTER',close,'CENTER',0,0)
closeText:SetText('X')
closeText:SetTextColor(0.22,0.13,0.08)
close:SetScript('OnEnter',function() closeText:SetTextColor(0.65,0.15,0.10) end)
close:SetScript('OnLeave',function() closeText:SetTextColor(0.22,0.13,0.08) end)
close:SetScript('OnClick',function() frame:Hide() end)
table.insert(UISpecialFrames,'LootBotNewsletterFrame')

local scroll=CreateFrame('ScrollFrame','LootBotNewsletterViewport',frame)
scroll:SetAllPoints(frame)
scroll:EnableMouse(true)
scroll:EnableMouseWheel(true)
local content=CreateFrame('Frame',nil,scroll)
scroll:SetScrollChild(content)
local paper=content:CreateTexture(nil,'ARTWORK')
paper:SetAllPoints(content)
-- Load a paper texture only when a reader opens an issue.
paper:SetTexCoord(0.125,0.875,0,1)

local fields,fieldsByKey={},{}
local applyZoom
local pageFields,activeFields={},nil
local pages,pageIndex={},1
local previousButton,nextButton,pageLabel,navigation
local renderPage
for _,slot in ipairs(slots) do
    local label=content:CreateFontString(nil,'OVERLAY','GameFontNormal')
    label:SetJustifyH(slot.center and 'CENTER' or 'LEFT')
    label:SetJustifyV('TOP')
    local color=slot.key=='headline' and accent or ink
    label:SetTextColor(color[1],color[2],color[3])
    label:SetText(slot.display)
    fields[#fields+1]={label=label,slot=slot}
    fieldsByKey[slot.key]=label
end

function News.Refresh()
    News.editionId=nil
    pages={};pageIndex=1;News.pageIndex=1;News.pageCount=1
    for _,field in ipairs(pageFields) do field.label:Hide() end
    activeFields=fields
    if navigation then navigation:Hide() end
    for _,field in ipairs(fields) do field.label:Show() end
    local edition=News.previewEdition or (LootBotGuildStatistics and LootBotGuildStatistics.CurrentEdition and LootBotGuildStatistics.CurrentEdition())
    if edition then
        News.waiting=edition.waiting==true
        if edition.launch and LootBotNewspaperEdition and not edition.pages then LootBotNewspaperEdition.Welcome(edition,GetServerTime()) end
        if edition.pages and #edition.pages>0 then
            pages=edition.pages
            if not edition.demo then News.editionId=edition.launch and 'welcome' or edition.id end
            News.pageCount=#pages
            renderPage()
            return edition
        end
        if edition.launch then
            for _,field in ipairs(fields) do field.label:Hide() end
            paper:SetTexture('Interface\\AddOns\\LootBot\\NewsletterWelcome.png')
            News.editionId='welcome'
            return edition
        end
        for key,value in pairs(edition.fields) do if fieldsByKey[key] then fieldsByKey[key]:SetText(value) end end
        fieldsByKey.masthead:SetText('ORIGINAL FORMALITIES\nWEEKLY')
        News.template=edition.template
        applyZoom(pageWidth)
        paper:SetTexture('Interface\\AddOns\\LootBot\\NewsletterHorde'..edition.template..'.png')
        News.editionId=edition.id
        return edition
    end
    paper:SetTexture('Interface\\AddOns\\LootBot\\NewsletterHorde1.png')
    News.template=1
    applyZoom(pageWidth)
    local snapshot=LootBotStatisticsProbe and LootBotStatisticsProbe.Capture()
    if not snapshot or snapshot.error or #snapshot.entries==0 then
        for _,field in ipairs(fields) do field.label:SetText(field.slot.display) end
        return snapshot
    end
    local byId={}
    for _,entry in ipairs(snapshot.entries) do byId[entry.id]=entry end
    local function value(id)
        local entry=byId[id]
        if not entry or entry.status~='available' then return '--' end
        if entry.numericValue then return string.format('%.0f',entry.numericValue) end
        return entry.value or '--'
    end
    local function positive(id)
        local entry=byId[id]
        return entry and entry.numericValue and entry.numericValue>0
    end
    local headline='A fresh start in Azeroth.'
    if positive(594) then headline='Hogger sends his regards.'
    elseif positive(114) then headline='Gravity remains undefeated.'
    elseif positive(1518) then headline='Gone fishing. Back eventually.'
    elseif positive(60) then headline='Another day. Another corpse run.'
    elseif positive(108) then headline='Local wildlife files a complaint.' end
    fieldsByKey.edition:SetText((snapshot.player or 'Adventurer')..'  |  CHARACTER EDITION  |  LIFETIME TOTALS')
    fieldsByKey.headline:SetText(headline)
    fieldsByKey.lead:SetText((snapshot.player or 'This character')..' has completed '..value(98)..' quests and killed '..value(107)..' creatures.\n\nBiggest hit: '..value(193)..'. Biggest heal: '..value(189)..'.\n\nEpic items looted: '..value(341)..'. Legendaries acquired: '..value(336)..'.\n\nRead directly from WoW. Missing values stay blank; weekly totals come after we have a baseline.')
    fieldsByKey.leftTitle:SetText('CORPSE RUNS')
    fieldsByKey.leftBody:SetText('ALL DEATHS  '..value(60)..'\nFALLING  '..value(114)..'\nDROWNING  '..value(112)..'\nFIRE / LAVA  '..value(115)..'\nHOGGER  '..value(594))
    local bossTotal,bossKnown=0,false
    for _,entry in ipairs(snapshot.entries) do
        if entry.category==14821 and entry.numericValue and not entry.hidden then
            bossTotal=bossTotal+entry.numericValue; bossKnown=true
        end
    end
    fieldsByKey.middleTitle:SetText('THE GRIND')
    fieldsByKey.middleBody:SetText('QUESTS  '..value(98)..'\nEPICS LOOTED  '..value(341)..'\nBOSS KILLS  '..(bossKnown and string.format('%.0f',bossTotal) or '--')..'\nNEED ROLLS  '..value(1044)..'\nHEALTH POTIONS  '..value(345))
    fieldsByKey.rightBody:SetText('FISH CAUGHT  '..value(1518)..'\nCRITTERS  '..value(108)..'\nHUGS  '..value(1042)..'\nWAVES  '..value(1065)..'\nFACEPALMS  '..value(1047))
    return snapshot
end

applyZoom=function(width)
    local oldWidth=pageWidth
    pageWidth=math.max(MIN_WIDTH,math.min(MAX_WIDTH,width))
    local scale=pageWidth/PAGE_W
    content:SetSize(pageWidth,PAGE_H*scale)
    for _,field in ipairs(activeFields or fields) do
        local slot,label=field.slot,field.label
        label:ClearAllPoints()
        local y=slot.y
        if #pages==0 and News.template==3 and (slot.key:find('Title') or slot.key:find('Body')) then y=y+50 end
        label:SetPoint('TOPLEFT',content,'TOPLEFT',slot.x*scale,-y*scale)
        label:SetSize(slot.w*scale,slot.h*scale)
        local modern=#pages>0
        local size=modern and slot.size or slot.key=='masthead' and 40 or slot.key=='headline' and 44 or slot.key=='lead' and 26
            or slot.key:find('Body') and 23 or slot.size
        local strong=modern and slot.strong or slot.key=='masthead' or slot.key=='headline' or slot.key:find('Title')
        local font=STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF'
        label:SetFont(font,math.max(9,size*scale))
    end
    local ratio=pageWidth/oldWidth
    local viewportH=fitWidth*PAGE_H/PAGE_W
    scroll:SetHorizontalScroll(math.max(0,math.min(pageWidth-fitWidth,
        (scroll:GetHorizontalScroll()+fitWidth/2)*ratio-fitWidth/2)))
    scroll:SetVerticalScroll(math.max(0,math.min(PAGE_H*scale-viewportH,
        (scroll:GetVerticalScroll()+viewportH/2)*ratio-viewportH/2)))
end

navigation=CreateFrame('Frame','LootBotNewsletterNavigation',frame)
navigation:SetSize(fitWidth,NAV_HEIGHT)
navigation:SetPoint('TOPLEFT',frame,'BOTTOMLEFT',0,-NAV_GAP)
local navBackground=navigation:CreateTexture(nil,'BACKGROUND')
navBackground:SetAllPoints(navigation);navBackground:SetColorTexture(0.08,0.065,0.045,0.88)
local function navButton(name,text,point,x)
    local control=CreateFrame('Button',name,navigation)
    control:SetSize(80,28);control:SetPoint(point,navigation,point,x,0)
    local label=control:CreateFontString(nil,'OVERLAY','GameFontNormal')
    label:SetPoint('CENTER');label:SetText(text);label:SetTextColor(0.92,0.85,0.69)
    control:SetScript('OnEnter',function() label:SetTextColor(1,1,0.9) end)
    control:SetScript('OnLeave',function() label:SetTextColor(0.92,0.85,0.69) end)
    return control
end
previousButton=navButton('LootBotNewsletterPreviousPage','< Föregående','LEFT',5)
nextButton=navButton('LootBotNewsletterNextPage','Nästa >','RIGHT',-5)
pageLabel=navigation:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
pageLabel:SetPoint('CENTER');pageLabel:SetTextColor(0.92,0.85,0.69)
renderPage=function()
    local page=pages[pageIndex]
    if not page then return end
    for _,field in ipairs(fields) do field.label:Hide() end
    for _,field in ipairs(pageFields) do field.label:Hide() end
    activeFields={}
    local printedBackground=({professions='NewsletterProfessions.png',dataLedger='NewsletterLedger.png',dataStories='NewsletterStories.png',dataSix='NewsletterStatistics.png'})[page.layout]
    local layout=LootBotNewspaperEdition.Layouts[page.layout]
    for i,slot in ipairs(layout) do
        local field=pageFields[i]
        if not field then
            field={label=content:CreateFontString(nil,'OVERLAY','GameFontNormal')};pageFields[i]=field
        end
        field.slot=slot
        field.label:SetJustifyH(slot.center and 'CENTER' or 'LEFT');field.label:SetJustifyV('TOP')
        field.label:SetTextColor(ink[1],ink[2],ink[3]);field.label:SetText(printedBackground and slot.key=='masthead' and '' or (page.fields[slot.key] or ''))
        field.label:Show();activeFields[#activeFields+1]=field
    end
    -- Keep the old texture name in shared issues for compatibility with older readers.
    local texture=printedBackground or page.texture
    if texture=='NewsletterFront2.png' then texture='NewsletterFront1.png' end
    paper:SetTexture('Interface\\AddOns\\LootBot\\'..texture)
    if not printedBackground and (page.layout:match('^data') or page.layout=='professions') then
        paper:SetTexCoord(.24,.46,.39,.68) -- clean unprinted paper, no decorative adverts
    else paper:SetTexCoord(.125,.875,0,1) end
    pageWidth=MIN_WIDTH;applyZoom(MIN_WIDTH)
    scroll:SetHorizontalScroll(0);scroll:SetVerticalScroll(0)
    News.pageIndex=pageIndex
    pageLabel:SetText(pageIndex..' / '..#pages..'  -  '..(News.waiting and 'Väntar på nästa nummer' or page.name))
    previousButton:SetEnabled(pageIndex>1);nextButton:SetEnabled(pageIndex<#pages)
    previousButton:SetAlpha(pageIndex>1 and 1 or 0.35);nextButton:SetAlpha(pageIndex<#pages and 1 or 0.35)
    if #pages>1 then navigation:Show() else navigation:Hide() end
end
function News.ChangePage(direction)
    pageIndex=math.max(1,math.min(#pages,pageIndex+direction));renderPage()
end
previousButton:SetScript('OnClick',function() News.ChangePage(-1) end)
nextButton:SetScript('OnClick',function() News.ChangePage(1) end)
navigation:Hide()

scroll:SetScript('OnMouseWheel',function(self,delta)
    applyZoom(pageWidth*(delta>0 and 1.15 or 1/1.15))
end)
scroll:SetScript('OnMouseDown',function(self)
    self.dragWindow=pageWidth<=fitWidth+1
    if self.dragWindow then frame:StartMoving(); return end
    local scale=UIParent:GetEffectiveScale()
    local x,y=GetCursorPosition()
    self.dragX,self.dragY=x/scale,y/scale
    self.startH,self.startV=self:GetHorizontalScroll(),self:GetVerticalScroll()
    self.dragging=true
end)
local function stopDragging(self)
    self.dragging=false; self.dragWindow=false; frame:StopMovingOrSizing()
end
scroll:SetScript('OnMouseUp',stopDragging)
scroll:SetScript('OnHide',stopDragging)
scroll:SetScript('OnUpdate',function(self)
    if not self.dragging then return end
    local scale=UIParent:GetEffectiveScale()
    local x,y=GetCursorPosition()
    self:SetHorizontalScroll(math.max(0,math.min(pageWidth-fitWidth,self.startH+self.dragX-x/scale)))
    self:SetVerticalScroll(math.max(0,math.min((pageWidth-fitWidth)*PAGE_H/PAGE_W,self.startV+y/scale-self.dragY)))
end)

local button=CreateFrame('Button','LootBotNewsletterMinimapButton',Minimap)
button:SetSize(31,31)
button:SetPoint('TOPLEFT',Minimap,'TOPLEFT',-11,11)
local buttonBackground=button:CreateTexture(nil,'BACKGROUND')
buttonBackground:SetSize(24,24)
buttonBackground:SetPoint('TOPLEFT',button,'TOPLEFT',2,-2)
buttonBackground:SetTexture('Interface\\Minimap\\UI-Minimap-Background')
local buttonIcon=button:CreateTexture(nil,'ARTWORK')
buttonIcon:SetSize(20,20)
buttonIcon:SetPoint('TOPLEFT',button,'TOPLEFT',7,-5)
-- Blizzard's portrait helper produces a circular icon on Classic as well.
if SetPortraitToTexture then SetPortraitToTexture(buttonIcon,'Interface\\Icons\\INV_Misc_Note_01')
else buttonIcon:SetTexture('Interface\\Icons\\INV_Misc_Note_01') end
local buttonBorder=button:CreateTexture(nil,'OVERLAY')
buttonBorder:SetSize(54,54)
buttonBorder:SetPoint('TOPLEFT',button,'TOPLEFT',0,0)
buttonBorder:SetTexture('Interface\\Minimap\\MiniMap-TrackingBorder')
button:SetHighlightTexture('Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight')
button:RegisterForClicks('LeftButtonUp','RightButtonUp')
button:SetScript('OnClick',function(_,mouseButton)
    if mouseButton=='RightButton' then
        if LootBotLevelToast then LootBotLevelToast.Options() end
    else News.Toggle() end
end)
button:SetScript('OnEnter',function(self)
    GameTooltip:SetOwner(self,'ANCHOR_LEFT')
    GameTooltip:SetText('LootBot')
    GameTooltip:AddLine('Left-click: newspaper',1,1,1)
    GameTooltip:AddLine('Right-click: options',1,1,1)
    GameTooltip:Show()
end)
button:SetScript('OnLeave',function() GameTooltip:Hide() end)
local badgeText=button:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
badgeText:SetPoint('TOPRIGHT',button,'TOPRIGHT',2,2)
badgeText:SetText('!')
badgeText:Hide()
function News.UpdateBadge()
    local edition=LootBotGuildStatistics and LootBotGuildStatistics.CurrentEdition and LootBotGuildStatistics.CurrentEdition()
    local key=UnitGUID('player')
    local read=LootBotDB and LootBotDB.newspaperRead and LootBotDB.newspaperRead[key]
    local token=edition and (edition.launch and 'welcome' or edition.id)
    if token and read~=token then badgeText:Show() else badgeText:Hide() end
end

function News.Toggle()
    if frame:IsShown() then frame:Hide()
    else News.Show() end
end
function News.Show(previewEdition)
    -- UI dimensions can change after the addon loads (login, scale, resolution).
    fitWidth=fittedWidth()
    MIN_WIDTH,MAX_WIDTH=fitWidth,fitWidth*2.5
    pageWidth=fitWidth
    frame:SetSize(fitWidth,fitWidth*PAGE_H/PAGE_W)
    frame:ClearAllPoints()
    frame:SetPoint('CENTER',UIParent,'CENTER',0,(NAV_HEIGHT+NAV_GAP)/2)
    navigation:SetSize(fitWidth,NAV_HEIGHT)
    News.previewEdition=previewEdition
    News.Refresh()
    frame:Show(); badgeText:Hide()
    if News.editionId then
        LootBotDB=LootBotDB or {}; LootBotDB.newspaperRead=LootBotDB.newspaperRead or {}
        LootBotDB.newspaperRead[UnitGUID('player')]=News.editionId
    end
end
function News.ShowDemo(fontChoice)
    News.demoFont=fontChoice or 'Crimson'
    if LootBotNewspaperEdition then News.Show(LootBotNewspaperEdition.Demo(GetServerTime())) end
end
applyZoom(pageWidth)
frame:Hide()
