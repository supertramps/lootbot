local G,N=LootBotGuildStatistics,LootBotNewspaperEdition
local now=GetServerTime(); local week=G.Week(now)-1
local first,last=345600+week*604800,345600+(week+1)*604800
local values={ [319]=8,[320]=2,[1044]=23,[1487]=40 }
local records={['Friend-Realm']={first=first,last=last-1,start=values,finish=values},
    ['Undefeated-Realm']={first=first,last=last-1,start={[319]=3,[320]=0},finish={[319]=3,[320]=0}},
    ['Unknown-Realm']={first=first,last=last-1,start={[319]=19},finish={[319]=19}}}
local edition=G.Edition({weeks={[week]=records}},now)
local text='';for _,page in ipairs(edition.pages) do for _,v in pairs(page.fields) do text=text..v..'\n' end end
assert(text:find('23 need-rolls',1,true) and text:find('40 killing blows',1,true))
assert(text:find('8 V / 2 F',1,true) and text:find('V/F 4.00',1,true) and text:find('80% vunna',1,true))
assert(text:find('Obesegrad',1,true) and not text:find('Unknown',1,true))
local db={startedWeek=week,weeks={[week]=records},checkpoints={['Friend-Realm']={values=values}}}
local draft,readings=G.PublicationDraft(db,now,{},function() return true end)
assert(readings['Friend-Realm'][319]==8 and readings['Friend-Realm'][320]==2 and readings['Friend-Realm'][1487]==40)
-- Bank only reads after opening/requesting, counts deposits and replaces snapshots.
local log={{'deposit','Friend',100000,0,0,0,1},{'withdraw','Other',500000,0,0,0,1},
    {'deposit','Friend',200000,0,0,0,2},{'depositSummary','Other',900000,0,0,0,1},
    {'deposit','Old',900000,0,0,20,0},{'deposit',nil,900000,0,0,0,0}}
MAX_GUILDBANK_TABS=8
local queried,reads=0,0
QueryGuildBankLog=function(tab) assert(tab==9); queried=queried+1 end
GetNumGuildBankMoneyTransactions=function() return #log end
GetGuildBankMoneyTransaction=function(i) assert(i>=1 and i<=#log);reads=reads+1;return table.unpack(log[i]) end
local B=LootBotGuildBankDonations
B.Capture(); assert(reads==0)
LootBotBankLogDriver.scripts.OnEvent(nil,'GUILDBANKFRAME_OPENED');assert(queried==1)
LootBotBankLogDriver.scripts.OnEvent(nil,'GUILDBANKLOG_UPDATE')
local rows=B.Report(now-86400,now+1);assert(#rows==1 and rows[1].value==300000)
B.Capture(); rows=B.Report(now-86400,now+1);assert(rows[1].value==300000)
local old=reads
LootBotBankLogDriver.scripts.OnEvent(nil,'GUILDBANKFRAME_CLOSED');B.Capture();assert(reads==old)
assert(not B.Report(now+1,now+604800))
