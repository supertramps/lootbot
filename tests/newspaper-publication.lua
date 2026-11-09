local G,P=LootBotGuildStatistics,LootBotNewspaperPublication
local now=345600+G.Week(GetServerTime())*604800+7200
local original=now
local names={['Chief-Realm']=true,['Friend-Realm']=true,['Third-Realm']=true,['Late-Realm']=true}
local online,clients,states,bus={},{},{},{}
local function time()return math.floor(now)end
local stats=G.New({}, {now=function()return original-604800 end,player=function()return 'Chief-Realm'end,member=function(n)return names[n]end,send=function()end})
stats:Capture({entries={{id=60,numericValue=80}},profile={money=100000,level=39,repairs=0}})
stats.api.now=time
stats:Capture({entries={{id=60,numericValue=100}},profile={money=200000,level=40,repairs=1000}})
local function add(name,saved)
    names[name]=true;online[name]=true;states[name]=saved or {}
    clients[name]=P.New(states[name],{
        now=time,clock=function()return now end,player=function()return name end,member=function(n)return names[n]end,
        knownRelay=function(n)return n=='Chief-Realm'end,canPublish=function()return name=='Chief-Realm'end,
        send=function(message,target)
            assert(#message<=255)
            assert(not message:find('[\128-\255]'),'wire chunks must remain ASCII even for accented names')
            bus[#bus+1]={sender=name,target=target,message=message}
        end
    });clients[name]:Join()
end
local dropped=false
local function drain()
    while #bus>0 do
        local message=table.remove(bus,1)
        for name,client in pairs(clients) do
            if online[name] and name~=message.sender and (not message.target or message.target==name) then
                if not dropped and name=='Friend-Realm' and not message.target and message.message:match('^D;%d+;%d+;2;') then dropped=true
                else client:Receive(message.message,message.sender,message.target and 'WHISPER' or 'GUILD') end
            end
        end
    end
end
local function pump(seconds)
    for _=1,seconds*2 do now=now+0.5;for name,client in pairs(clients)do if online[name]then client:Tick()end end;drain()end
end
add('Chief-Realm');add('Friend-Realm');add('Third-Realm')
pump(10)
assert(not clients['Chief-Realm']:Latest())
local draft,readings=G.PublicationDraft(stats.db,time(),{},nil,original-604800)
assert(not clients['Friend-Realm']:Publish(draft))
assert(clients['Chief-Realm']:Publish(draft))
local issueId=draft.id
pump(180)
local frozen=states['Chief-Realm'].issues[issueId]
assert(frozen and frozen.edition.manual)
assert(states['Friend-Realm'].issues[issueId].payload==frozen.payload and states['Third-Realm'].issues[issueId].payload==frozen.payload)
assert(not next(states['Friend-Realm'].issues[issueId].edition.readings))
assert(dropped,'simulation should exercise lost broadcast recovery')
local oldPayload=frozen.payload
add('Chief-Realm',{});pump(120)
assert(states['Chief-Realm'].issues[issueId].payload==oldPayload)
online['Chief-Realm']=false
add('Newcomer-Realm');pump(120)
assert(states['Newcomer-Realm'].issues[issueId].payload==oldPayload)
local restored=states['Newcomer-Realm']
add('Newcomer-Realm',restored)
assert(clients['Newcomer-Realm']:Get().id==issueId)
now=now+604800;pump(60)
assert(clients['Friend-Realm']:Latest().edition.id==issueId)
online['Chief-Realm']=true
local last=time()
assert(stats:Merge('Late-Realm',G.Week(last),last-120,last,{[60]=20},{[60]=50}))
local nextDraft=G.PublicationDraft(stats.db,time(),readings,nil,issueId)
assert(clients['Chief-Realm']:Publish(nextDraft));pump(180)
local nextIssue=states['Chief-Realm'].issues[nextDraft.id]
assert(nextIssue and nextIssue.edition.publisher=='Chief-Realm')
assert(states['Friend-Realm'].issues[nextDraft.id].payload==nextIssue.payload)
assert(states['Chief-Realm'].issues[issueId].payload==oldPayload)
local corrupt=nextIssue.payload:gsub('NP2','NP1',1)
assert(not P.Decode(corrupt,time()))
assert(not clients['Friend-Realm']:Store(corrupt,nextIssue.hash,'Chief-Realm'))
local unicode=P.Decode(nextIssue.payload,time())
unicode.pages[1].fields.headline='Jörgen found a story.'
local encoded=P.Encode(unicode,'Chief-Realm',unicode.publishedAt)
assert(not encoded:find('[\128-\255]') and P.Decode(encoded,time()).pages[1].fields.headline=='Jörgen found a story.')
