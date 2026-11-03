-- Supplemental raw character metrics; no screen reading or game actions.
LootBotNewsletterMetrics={ids={money=900001,level=900002,repairs=900003}}
local M=LootBotNewsletterMetrics
local function number(value)
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value)=='number' and value==value and value>=0 and value<=1e15 then return value end
end
local function read(fn,...)
    if type(fn)~='function' then return nil end
    local ok,value=pcall(fn,...)
    return ok and number(value) or nil
end
local function saved()
    LootBotDB=LootBotDB or {}; LootBotDB.newsletterRepairs=LootBotDB.newsletterRepairs or {}
    local key=UnitGUID('player')
    if not key then return nil end
    LootBotDB.newsletterRepairs[key]=LootBotDB.newsletterRepairs[key] or 0
    return key
end
function M.Profile()
    local key=saved()
    return {money=read(GetMoney),level=read(UnitLevel,'player'),
        repairs=key and LootBotDB.newsletterRepairs[key] or nil}
end
local driver=CreateFrame('Frame','LootBotNewsletterMetricsDriver')
local open,balance,quote,pending,hooked=false,nil,nil,nil,false
local function refresh()
    balance=read(GetMoney)
    quote=open and read(GetRepairAllCost) or nil
end
local function confirm()
    if not pending then return end
    local money,cost=read(GetMoney),read(GetRepairAllCost)
    -- Require both an exact personal payment and a cleared repair quote.
    -- Guild-bank repairs, failed repairs and ambiguous transactions are excluded.
    if money and cost==0 and pending.before-money==pending.cost then
        local key=saved()
        if key then LootBotDB.newsletterRepairs[key]=LootBotDB.newsletterRepairs[key]+pending.cost end
        pending=nil
    elseif GetTime()-pending.at>3 then pending=nil end
end
local function hook()
    if hooked or type(hooksecurefunc)~='function' or type(RepairAllItems)~='function' then return end
    hooked=true
    hooksecurefunc('RepairAllItems',function(guildFunds)
        if open and not guildFunds and balance and quote and quote>0 then
            pending={before=balance,cost=quote,at=GetTime()}
            confirm()
            if C_Timer and C_Timer.After then C_Timer.After(0.25,function() confirm(); refresh() end) end
        end
    end)
end
for _,event in ipairs({'PLAYER_LOGIN','PLAYER_ENTERING_WORLD','MERCHANT_SHOW','MERCHANT_CLOSED','MERCHANT_UPDATE','PLAYER_MONEY','UPDATE_INVENTORY_DURABILITY'}) do driver:RegisterEvent(event) end
driver:SetScript('OnEvent',function(_,event)
    if event=='MERCHANT_SHOW' then open=true; pending=nil end
    if event=='PLAYER_LOGIN' or event=='PLAYER_ENTERING_WORLD' then saved(); hook() end
    confirm()
    if event=='MERCHANT_CLOSED' then open=false; pending=nil end
    refresh()
end)
