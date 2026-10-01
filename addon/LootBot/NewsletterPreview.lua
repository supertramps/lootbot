-- Classic-only visual prototype. Everything on this page is made-up sample data.
-- It does not collect statistics, send addon messages, or contact the relay.
LootBotNewsletterPreview = {}
local News = LootBotNewsletterPreview

local PAGE_W, PAGE_H = 1086, 1448
local pageWidth = 515
local MIN_WIDTH, MAX_WIDTH = 390, 1050
local ink = {0.19, 0.13, 0.09}
local accent = {0.38, 0.12, 0.10}
local slots = {
    {key='masthead', x=260,y=100,w=566,h=135,size=55,center=true,display='THE GUILD GAZETTE'},
    {key='edition', x=64,y=283,w=958,h=29,size=19,center=true,display='SAMPLE ISSUE  |  WEEK OF 1 OCTOBER  |  ALL FIGURES ARE MADE UP'},
    {key='headline', x=66,y=351,w=954,h=104,size=48,center=true,display='Twenty heroes. One very busy graveyard.'},
    {key='lead', x=58,y=515,w=548,h=369,size=28,display='The guild had a week to remember. Some of us would rather forget the walk back to our corpses.\n\nGruk led the death count with 18. Mara brought home the most epic loot. Nim caught 98 fish and insists this counts as progress.\n\nSee the numbers below. The names are fake; the newspaper is a preview.'},
    {key='leftTitle', x=52,y=957,w=282,h=42,size=29,center=true,display='GRAVEYARD REGULARS'},
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
frame:SetSize(680,700)
frame:SetPoint('CENTER')
frame:SetFrameStrata('DIALOG')
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag('LeftButton')
frame:SetScript('OnDragStart',function(self) self:StartMoving() end)
frame:SetScript('OnDragStop',function(self) self:StopMovingOrSizing() end)
local surround=frame:CreateTexture(nil,'BACKGROUND')
surround:SetAllPoints(frame)
surround:SetColorTexture(0.09,0.10,0.10,0.96)

local title=frame:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
title:SetPoint('TOPLEFT',frame,'TOPLEFT',18,-14)
title:SetText('Guild Gazette  -  sample issue')

local close=CreateFrame('Button',nil,frame,'UIPanelButtonTemplate')
close:SetSize(34,24)
close:SetPoint('TOPRIGHT',frame,'TOPRIGHT',-13,-10)
close:SetText('X')
close:SetScript('OnClick',function() frame:Hide() end)

local scroll=CreateFrame('ScrollFrame',nil,frame)
scroll:SetPoint('TOPLEFT',frame,'TOPLEFT',17,-45)
scroll:SetPoint('BOTTOMRIGHT',frame,'BOTTOMRIGHT',-17,51)
scroll:EnableMouse(true)
scroll:EnableMouseWheel(true)
local content=CreateFrame('Frame',nil,scroll)
scroll:SetScrollChild(content)
local paper=content:CreateTexture(nil,'ARTWORK')
paper:SetAllPoints(content)
paper:SetTexture('Interface\\AddOns\\LootBot\\NewsletterPage.png')
paper:SetTexCoord(0.125,0.875,0,1)

local fields={}
for _,slot in ipairs(slots) do
    local label=content:CreateFontString(nil,'OVERLAY','GameFontNormal')
    label:SetJustifyH(slot.center and 'CENTER' or 'LEFT')
    label:SetJustifyV('TOP')
    local color=slot.key=='headline' and accent or ink
    label:SetTextColor(color[1],color[2],color[3])
    label:SetText(slot.display)
    fields[#fields+1]={label=label,slot=slot}
end

local zoomText=frame:CreateFontString(nil,'OVERLAY','GameFontNormal')
zoomText:SetPoint('BOTTOM',frame,'BOTTOM',0,17)
local function applyZoom(width)
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
    zoomText:SetText('Zoom: '..math.floor(pageWidth/515*100+0.5)..'%  |  Mouse wheel scrolls; drag page to pan')
end

local minus=CreateFrame('Button',nil,frame,'UIPanelButtonTemplate')
minus:SetSize(29,27)
minus:SetPoint('BOTTOMLEFT',frame,'BOTTOMLEFT',16,11)
minus:SetText('-')
minus:SetScript('OnClick',function() applyZoom(pageWidth/1.25) end)
local plus=CreateFrame('Button',nil,frame,'UIPanelButtonTemplate')
plus:SetSize(29,27)
plus:SetPoint('BOTTOMRIGHT',frame,'BOTTOMRIGHT',-16,11)
plus:SetText('+')
plus:SetScript('OnClick',function() applyZoom(pageWidth*1.25) end)

scroll:SetScript('OnMouseWheel',function(self,delta)
    self:SetVerticalScroll(math.max(0,self:GetVerticalScroll()-delta*48))
end)
scroll:SetScript('OnMouseDown',function(self)
    local scale=UIParent:GetEffectiveScale()
    local x,y=GetCursorPosition()
    self.dragX,self.dragY=x/scale,y/scale
    self.startH,self.startV=self:GetHorizontalScroll(),self:GetVerticalScroll()
    self.dragging=true
end)
scroll:SetScript('OnMouseUp',function(self) self.dragging=false end)
scroll:SetScript('OnHide',function(self) self.dragging=false end)
scroll:SetScript('OnUpdate',function(self)
    if not self.dragging then return end
    local scale=UIParent:GetEffectiveScale()
    local x,y=GetCursorPosition()
    self:SetHorizontalScroll(math.max(0,self.startH+self.dragX-x/scale))
    self:SetVerticalScroll(math.max(0,self.startV+y/scale-self.dragY))
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
    else frame:Show(); badge:Hide(); badgeText:Hide() end
end
function News.Show()
    frame:Show(); badge:Hide(); badgeText:Hide()
end
applyZoom(pageWidth)
frame:Hide()
