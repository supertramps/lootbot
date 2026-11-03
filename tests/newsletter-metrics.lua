local money,cost=500000,12345
local hook,callback
function GetMoney() return money end
function GetRepairAllCost() return cost end
function RepairAllItems() end
function hooksecurefunc(name,fn) assert(name=='RepairAllItems');hook=fn end
C_Timer={After=function(_,fn) callback=fn end}
local driver=LootBotNewsletterMetricsDriver
driver.scripts.OnEvent(driver,'PLAYER_LOGIN')
driver.scripts.OnEvent(driver,'MERCHANT_SHOW')
assert(type(hook)=='function')
hook(false)
assert(LootBotNewsletterMetrics.Profile().repairs==0,'quote alone is not spending')
money=money-cost;cost=0
driver.scripts.OnEvent(driver,'PLAYER_MONEY')
assert(LootBotNewsletterMetrics.Profile().repairs==12345)
driver.scripts.OnEvent(driver,'UPDATE_INVENTORY_DURABILITY');callback()
assert(LootBotNewsletterMetrics.Profile().repairs==12345,'payment must not double count')
cost=500;driver.scripts.OnEvent(driver,'MERCHANT_UPDATE')
hook(true);cost=0;driver.scripts.OnEvent(driver,'MERCHANT_UPDATE')
assert(LootBotNewsletterMetrics.Profile().repairs==12345,'guild repairs are excluded')
cost=700;driver.scripts.OnEvent(driver,'MERCHANT_UPDATE');hook(false)
money=money-200;cost=0;MockTime=MockTime+4
driver.scripts.OnEvent(driver,'PLAYER_MONEY')
assert(LootBotNewsletterMetrics.Profile().repairs==12345,'unrelated money changes are not repair bills')
local profile=LootBotNewsletterMetrics.Profile()
assert(profile.money==money and profile.level==40)
local secret={}
function issecretvalue(v) return v==secret end
GetMoney=function() return secret end
assert(LootBotNewsletterMetrics.Profile().money==nil)

-- Profile readings survive clients without a statistics catalogue and sync as numeric rows.
local now=GetServerTime()
local engine=LootBotGuildStatistics.New({}, {now=function() return now end,player=function()return 'Alex-Realm'end,member=function()return true end,send=function()end})
engine:Capture({error='Missing statistics API',profile={money=500000,level=10,repairs=0},entries={}})
now=now+1800
engine:Capture({profile={money=400000,level=11,repairs=12345},entries={}})
local row=engine.db.weeks[LootBotGuildStatistics.Week(now)]['Alex-Realm']
assert(row.start[900001]==500000 and row.finish[900001]==400000)
assert(row.finish[900002]==11 and row.finish[900003]==12345)
