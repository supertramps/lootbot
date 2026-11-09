-- Read-only money-log snapshot. Never adds repeated snapshots together or moves gold.
LootBotGuildBankDonations={}
local B=LootBotGuildBankDonations
local open,requested=false,false
local driver=CreateFrame('Frame','LootBotBankLogDriver')
local function number(v) return not (issecretvalue and issecretvalue(v)) and type(v)=='number' and v>=0 and v<=1e15 end
local function guildKey()
    local name=GetGuildInfo('player')
    return name and GetRealmName()..':'..name
end
function B.Request()
    if not open then return 'Open the guild bank first.' end
    if type(QueryGuildBankLog)~='function' or type(MAX_GUILDBANK_TABS)~='number' then return 'Money-log API unavailable.' end
    requested=true
    QueryGuildBankLog(MAX_GUILDBANK_TABS+1)
    return 'Requested the visible guild-bank money log.'
end
function B.Capture()
    if not open or not requested or type(GetNumGuildBankMoneyTransactions)~='function'
        or type(GetGuildBankMoneyTransaction)~='function' then return end
    local key=guildKey(); if not key then return end
    local count=GetNumGuildBankMoneyTransactions()
    if not number(count) or count>1000 or count%1~=0 then return end
    local now=GetServerTime(); local entries={}
    for i=1,count do
        local kind,name,amount,years,months,days,hours=GetGuildBankMoneyTransaction(i)
        if not (issecretvalue and (issecretvalue(kind) or issecretvalue(name))) and kind=='deposit'
            and type(name)=='string' and #name<=100 and not name:find('[|%c]')
            and number(amount) and amount>0 and number(years) and number(months) and number(days) and number(hours)
            and years==0 and months==0 and days<=14 then
            entries[#entries+1]={name=name,amount=amount,at=now-days*86400-hours*3600}
        end
    end
    LootBotDB=LootBotDB or {}; LootBotDB.bankDonationSnapshots=LootBotDB.bankDonationSnapshots or {}
    LootBotDB.bankDonationSnapshots[key]={capturedAt=now,entries=entries,visibleTransactions=count}
end
function B.Report(first,last)
    local key=guildKey()
    local snapshot=key and LootBotDB and LootBotDB.bankDonationSnapshots and LootBotDB.bankDonationSnapshots[key]
    if not snapshot or snapshot.capturedAt<first or snapshot.capturedAt>last+86400 then return end
    local totals={}
    for _,entry in ipairs(snapshot.entries) do
        if entry.at>=first and entry.at<last then totals[entry.name]=(totals[entry.name] or 0)+entry.amount end
    end
    local rows={}; for name,value in pairs(totals) do rows[#rows+1]={name=name:match('^[^-]+') or name,fullName=name,value=value} end
    table.sort(rows,function(a,b) return a.value==b.value and a.fullName<b.fullName or a.value>b.value end)
    if #rows>0 then return rows,snapshot.capturedAt end
end
driver:SetScript('OnEvent',function(_,event)
    if event=='GUILDBANKFRAME_OPENED' then open=true; requested=false; B.Request()
    elseif event=='GUILDBANKFRAME_CLOSED' then open=false; requested=false
    elseif event=='GUILDBANKLOG_UPDATE' then B.Capture() end
end)
for _,event in ipairs({'GUILDBANKFRAME_OPENED','GUILDBANKFRAME_CLOSED','GUILDBANKLOG_UPDATE'}) do driver:RegisterEvent(event) end
