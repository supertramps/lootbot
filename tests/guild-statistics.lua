local G=LootBotGuildStatistics
local now=345600+2900*604800+3600
local guild={['Alex-Realm']=true,['Friend-Realm']=true}
local sentA,sentB={},{}
local function api(name,sent)
    return {now=function() return now end,player=function() return name end,
        member=function(n) return guild[n]==true end,
        send=function(m,target) assert(#m<=255); sent[#sent+1]={m=m,target=target} end}
end
local a=G.New({},api('Alex-Realm',sentA))
local b=G.New({},api('Friend-Realm',sentB))
local function snapshot(deaths,quests,fish,hit)
    return {entries={{id=60,numericValue=deaths},{id=98,numericValue=quests},
        {id=1518,numericValue=fish},{id=193,numericValue=hit},{id=341,status='unknown'}}}
end
local function flush(engine,sent,peer,sender)
    while #engine.queue>0 do engine:Tick() end
    for i=#sent,1,-1 do peer:Receive(sent[i].m,sender,sent[i].target and 'WHISPER' or 'GUILD') end
    for _,row in ipairs(sent) do peer:Receive(row.m,sender,row.target and 'WHISPER' or 'GUILD') end
    for i=#sent,1,-1 do sent[i]=nil end
end
a:Capture(snapshot(100,1000,300,100))
b:Capture(snapshot(5,200,10,80))
flush(a,sentA,b,'Alex-Realm'); flush(b,sentB,a,'Friend-Realm')
now=now+3600
a:Capture(snapshot(108,1005,309,100)); b:Capture(snapshot(6,210,12,80))
flush(a,sentA,b,'Alex-Realm'); flush(b,sentB,a,'Friend-Realm')
local welcome=G.Edition(b.db,now)
assert(welcome.launch and welcome.partial and welcome.fields.masthead:find('ORIGINAL FORMALITIES',1,true))
local edition=G.Edition(b.db,now+604800)
assert(not edition.partial and edition.fields.headline:find('Alex',1,true))
assert(edition.fields.headline:find('8',1,true),'weekly delta must not be lifetime 108')
assert(not edition.fields.headline:find('Realm',1,true))
assert(edition.fields.leftBody:find('Guild total: 9',1,true))
assert(edition.fields.middleBody:find('Guild total: 15',1,true))
assert(a.db.weeks[edition.id]['Friend-Realm'].finish[341]==nil,'unknown must not become zero')
local previous=edition.id
now=345600+(previous+1)*604800+3600
edition=G.Edition(a.db,now)
assert(not edition.partial and edition.id==previous)
-- A new week never absorbs increases accumulated while offline between weeks.
a:Capture(snapshot(130,1500,500,100))
now=now+3600; a:Capture(snapshot(131,1502,504,250))
local fresh=G.Edition({weeks={[G.Week(now)]=a.db.weeks[G.Week(now)]}},now+604800)
assert(fresh.fields.headline=='Alex landed a 250 hit.')
assert(fresh.fields.lead:find('previous biggest hit',1,true))
assert(fresh.fields.leftBody:find('Guild total: 1',1,true))
-- Counter resets produce no negative totals or fabricated recovered activity.
now=now+3600; a:Capture(snapshot(1,1502,504,250))
local reset=G.Edition({weeks={[G.Week(now)]=a.db.weeks[G.Week(now)]}},now+604800)
assert(not reset.fields.leftBody:find('%-%d'))
-- Membership, timestamps and size bounds apply to received data.
local week=G.Week(now)
assert(not a:Merge('Stranger-Realm',week,now-10,now,{[60]=0},{[60]=10}))
assert(not a:Merge('Friend-Realm',week,now-10,now+1000,{[60]=0},{[60]=10}))
assert(not a:Merge('Friend-Realm',week,now-604800,now,{[60]=0},{[60]=10}))
b:Receive('D;bad;Alex-Realm;'..week..';'..now..';'..now..';1;1;60=0=999','Stranger-Realm','GUILD')
assert(b.db.weeks[week]==nil)
-- Late join gets cached readings for offline peers from one selected member.
local c=G.New({},api('Friend-Realm',{}))
c:Join(); c:Receive('OFFER','Alex-Realm','WHISPER')
a:Receive('CACHE','Friend-Realm','WHISPER')
flush(a,sentA,c,'Alex-Realm')
assert(c.db.weeks[previous]['Friend-Realm'].finish[60]==6)
-- Large catalogue is chunked, reassembled out of order and deduplicated.
local entries={}; for i=1,201 do entries[i]={id=10000+i,numericValue=i*100} end
now=now+1800; a:Capture({entries=entries})
assert(#a.queue>1)
flush(a,sentA,c,'Alex-Realm')
assert(c.db.weeks[week]['Alex-Realm'].finish[10201]==20100)
-- Retention bounded to four weekly buckets; gaps never borrow older baselines.
now=now+4*604800; a:Prune()
assert(a.db.weeks[previous]==nil)
local t1=G.Edition({weeks={[G.Week(now)]={['Alex-Realm']={first=now-10,last=now,start={[60]=0},finish={[60]=0}}}}},now+604800)
local t2=G.Edition({weeks={[G.Week(now)+1]={['Alex-Realm']={first=now+604800-10,last=now+604800,start={[60]=0},finish={[60]=0}}}}},now+2*604800)
assert(t1.template~=t2.template and t1.metrics[1]~=t2.metrics[1])
