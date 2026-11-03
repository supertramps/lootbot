local G,P=LootBotGuildStatistics,LootBotNewspaperPublication
local now=345600+G.Week(GetServerTime())*604800+7200
local original=now
local names={['Chief-Realm']=true,['Friend-Realm']=true,['Third-Realm']=true,['Late-Realm']=true}
local online,clients,states,bus,builds={},{},{},{},{}
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
        revision=function()return stats.db.revision or 0 end,
        build=function(printed)builds[name]=(builds[name]or 0)+1;return G.PublicationDraft(stats.db,time(),printed)end,
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
pump(180)
local week=G.Week(time())-1
local frozen=states['Chief-Realm'].issues[week]
assert(frozen and builds['Chief-Realm']==1)
assert(states['Friend-Realm'].issues[week].payload==frozen.payload and states['Third-Realm'].issues[week].payload==frozen.payload)
assert(states['Friend-Realm'].printedReadings['Chief-Realm'][60]==100)
assert(not builds['Friend-Realm'] and not builds['Third-Realm'],'readers must never generate their own issue')
assert(dropped,'simulation should exercise lost broadcast recovery')
local oldPayload=frozen.payload
-- Recover the publisher's fixed issue from peer copies rather than rebuilding
-- after losing its local publication file.
local beforeBuild=builds['Chief-Realm']
add('Chief-Realm',{});pump(100)
assert(states['Chief-Realm'].issues[week].payload==oldPayload and builds['Chief-Realm']==beforeBuild)
-- An already published paper stays fixed despite new and late reports.
local last=345600+G.Week(time())*604800-3600
assert(stats:Merge('Late-Realm',week,last-86400,last,{[60]=20},{[60]=50}))
pump(20)
assert(states['Chief-Realm'].issues[week].payload==oldPayload and builds['Chief-Realm']==1)
-- A reader with no local file gets the identical issue from another reader
-- while the publishing character is offline; no .exe or publisher is involved.
online['Chief-Realm']=false
add('Newcomer-Realm');pump(120)
assert(states['Newcomer-Realm'].issues[week].payload==oldPayload)
local restored=states['Newcomer-Realm']
add('Newcomer-Realm',restored)
assert(clients['Newcomer-Realm']:Get().id==week)
-- Nobody else publishes a replacement while the authority is offline.
now=345600+(G.Week(time())+1)*604800+3600
pump(80)
assert(not states['Friend-Realm'].issues[week+1])
online['Chief-Realm']=true
pump(180)
local nextIssue=states['Chief-Realm'].issues[week+1]
assert(nextIssue and nextIssue.edition.publisher=='Chief-Realm')
local text='';for _,page in ipairs(nextIssue.edition.pages)do for _,v in pairs(page.fields)do text=text..v end end
assert(text:find('30',1,true) and text:find('Late',1,true),'late historical activity must enter the next paper')
assert(states['Friend-Realm'].issues[week+1].payload==nextIssue.payload)
assert(states['Chief-Realm'].printedReadings['Late-Realm'][60]==50)
local corrupt=nextIssue.payload:gsub('NP1','NP2',1)
assert(not P.Decode(corrupt,time()))
assert(not clients['Friend-Realm']:Store(corrupt,nextIssue.hash,'Chief-Realm'))
local before=states['Friend-Realm'].issues[week+1].payload
clients['Friend-Realm']:Receive('R','Outsider-Realm','GUILD')
clients['Friend-Realm']:Receive(string.rep('D',256),'Third-Realm','GUILD')
assert(states['Friend-Realm'].issues[week+1].payload==before)
-- Accented names round-trip through percent-encoded, chunk-safe payloads.
local unicode=P.Decode(nextIssue.payload,time())
unicode.pages[1].fields.headline='Jörgen found a story.'
local encoded=P.Encode(unicode,'Chief-Realm',time())
assert(not encoded:find('[\128-\255]') and P.Decode(encoded,time()).pages[1].fields.headline=='Jörgen found a story.')
