-- Paper viewer. Uses this character's API statistics when available; the
-- clearly labelled sample issue is the fallback for clients without data.
LootBotNewsletterPreview = {}
local News = LootBotNewsletterPreview

local PAGE_W, PAGE_H = 1086, 1448
local fitWidth = math.min(515,UIParent:GetHeight()*0.88*PAGE_W/PAGE_H,UIParent:GetWidth()*0.8)
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
paper:SetTexture('Interface\\AddOns\\LootBot\\NewsletterPage.png')
paper:SetTexCoord(0.125,0.875,0,1)

local fields,fieldsByKey={},{}
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

local function applyZoom(width)
    local oldWidth=pageWidth
    pageWidth=math.max(MIN_WIDTH,math.min(MAX_WIDTH,width))
    local scale=pageWidth/PAGE_W
    content:SetSize(pageWidth,PAGE_H*scale)
    for _,field in ipairs(fields) do
        local slot,label=field.slot,field.label
        label:ClearAllPoints()
        label:SetPoint('TOPLEFT',content,'TOPLEFT',slot.x*scale,-slot.y*scale)
        label:SetSize(slot.w*scale,slot.h*scale)
        label:SetFont((slot.key=='masthead' or slot.key=='headline') and 'Fonts\\MORPHEUS.TTF' or STANDARD_TEXT_FONT,
            math.max(9,slot.size*scale))
    end
    local ratio=pageWidth/oldWidth
    local viewportH=fitWidth*PAGE_H/PAGE_W
    scroll:SetHorizontalScroll(math.max(0,math.min(pageWidth-fitWidth,
        (scroll:GetHorizontalScroll()+fitWidth/2)*ratio-fitWidth/2)))
    scroll:SetVerticalScroll(math.max(0,math.min(PAGE_H*scale-viewportH,
        (scroll:GetVerticalScroll()+viewportH/2)*ratio-viewportH/2)))
end

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
button:SetNormalTexture('Interface\\Icons\\INV_Misc_Note_01')
button:SetHighlightTexture('Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight')
button:SetScript('OnClick',function() News.Toggle() end)
local badge=button:CreateTexture(nil,'OVERLAY')
badge:SetSize(17,17)
badge:SetPoint('TOPRIGHT',button,'TOPRIGHT',5,5)
badge:SetColorTexture(0.64,0.13,0.12,1)
local badgeText=button:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
badgeText:SetPoint('CENTER',badge,'CENTER',0,0)
badgeText:SetText('1')

function News.Toggle()
    if frame:IsShown() then frame:Hide()
    else News.Show() end
end
function News.Show()
    News.Refresh()
    frame:Show(); badge:Hide(); badgeText:Hide()
end
applyZoom(pageWidth)
frame:Hide()
