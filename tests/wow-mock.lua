MockTime = 1
MockHeight = 1440
MockScale = 0.8
UIParent = { GetEffectiveScale = function() return MockScale end }
Minimap = {}
STANDARD_TEXT_FONT = 'Fonts/FRIZQT__.TTF'
function GetCursorPosition() return 500,500 end
function GetPhysicalScreenSize() return MockHeight * 16 / 9, MockHeight end
SlashCmdList = {}
LOOT_ITEM_SELF = 'You receive loot: %s.'
LOOT_ITEM_SELF_MULTIPLE = 'You receive loot: %sx%d.'
LOOT_ITEM_PUSHED_SELF = 'You receive item: %s.'
LOOT_ITEM_PUSHED_SELF_MULTIPLE = 'You receive item: %sx%d.'
function GetTime() return MockTime end
function GetServerTime() return 1780000000 end
function UnitName() return 'Alex' end
function UnitGUID() return 'Player-1-ABC123' end
MockLevel = 40
function UnitLevel() return MockLevel end
function GetGuildInfo() return 'TestGuild' end
function IsInGuild() return true end
function GetNumGuildMembers() return 2 end
function GetGuildRosterInfo(i) return i==1 and 'Alex-TestRealm' or 'Friend-TestRealm' end
C_GuildInfo={GuildRoster=function() end}
C_ChatInfo={RegisterAddonMessagePrefix=function() end,SendAddonMessage=function() end}
function GetRealmName() return 'TestRealm' end
function GetBuildInfo() return '1.15.0', '00000', '', 11500 end
function print() end
function CreateFrame(_, name)
    local frame = { scripts={}, textures={}, shown=true }
    local nop = function() end
    for _, method in ipairs({'SetFrameStrata','SetFrameLevel','EnableMouse','SetAlpha','SetScale','SetSize','ClearAllPoints','SetPoint','RegisterEvent',
        'SetClampedToScreen','SetMovable','RegisterForDrag','StartMoving','StopMovingOrSizing','EnableMouseWheel',
        'SetNormalTexture','SetHighlightTexture','SetAllPoints'}) do frame[method]=nop end
    function frame:SetScale(scale) self.scale=scale end
    function frame:SetSize(width,height) self.width=width; self.height=height end
    function frame:SetPoint(_, _, _, x, y) self.x=x; self.y=y end
    function frame:SetScript(event, fn) self.scripts[event]=fn end
    function frame:Show() self.shown=true end
    function frame:Hide() self.shown=false end
    function frame:IsShown() return self.shown end
    function frame:SetText(value) self.text=value end
    function frame:SetScrollChild(child) self.scrollChild=child end
    function frame:SetHorizontalScroll(value) self.horizontalScroll=value end
    function frame:GetHorizontalScroll() return self.horizontalScroll or 0 end
    function frame:SetVerticalScroll(value) self.verticalScroll=value end
    function frame:GetVerticalScroll() return self.verticalScroll or 0 end
    function frame:CreateTexture()
        local texture = { SetSize=nop, SetPoint=nop, SetAllPoints=nop, SetTexture=nop, SetTexCoord=nop, Hide=nop }
        function texture:SetColorTexture(r) self.color=r end
        self.textures[#self.textures+1]=texture
        return texture
    end
    function frame:CreateFontString(_, _, inherits)
        local label={ SetPoint=nop, ClearAllPoints=nop, SetSize=nop, SetJustifyH=nop, SetJustifyV=nop,
            SetTextColor=nop, Hide=nop, font=inherits }
        function label:SetFont(path) self.font=path end
        function label:SetText(value)
            assert(self.font,'FontString:SetText(): Font not set')
            self.text=value
        end
        self.labels=self.labels or {}; self.labels[#self.labels+1]=label
        return label
    end
    if name then _G[name]=frame end
    return frame
end
function ReadMarker()
    local bytes = {}
    for b=0,255 do
        local value=0
        for bit=0,7 do value=value*2+LootBotMarker.textures[b*8+bit+1].color end
        bytes[#bytes+1]=string.char(value)
    end
    return table.concat(bytes)
end
