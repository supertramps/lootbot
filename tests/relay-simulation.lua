local time, now, network, nodes = 0, 1780000000, {}, {}
local dropAck=true
local function make(name,guid,db)
    local node={online=true,draws=0}
    node.core=LootBotRelay.new(db or {},{
        player=name,guid=guid,time=function() return time end,now=function() return now end,
        guild=function() return 'Guild@Realm' end,
        member=function(sender) return sender=='Host-Realm' or sender=='Friend-Realm' or sender=='Backup-Realm' end,
        draw=function(packet) if packet then node.draws=node.draws+1 end end,
        send=function(message,target) network[#network+1]={from=name,target=target,message=message} end
    })
    nodes[name]=node; return node
end
local function tick(seconds)
    for step=1,seconds*10 do
        time=time+0.1
        for _,node in pairs(nodes) do if node.online then node.core:tick() end end
        local batch=network; network={}
        for _,msg in ipairs(batch) do
            if dropAck and msg.message:sub(1,2)=='A\t' then dropAck=false
            else
                for name,node in pairs(nodes) do
                    if node.online and name~=msg.from and (not msg.target or msg.target==name) then
                        node.core:receive(msg.message,msg.target and 'WHISPER' or 'GUILD',msg.from)
                    end
                end
            end
        end
    end
end
local host=make('Host-Realm','Player-1-HOST')
local friend=make('Friend-Realm','Player-1-FRIEND')
friend.core:record({kind='loot',itemId=123,quality=4,quantity=2,itemName='Épée'})
assert(#friend.core.db.own==1 and friend.draws==0)
host.core:setRelay(true)
tick(55)
assert(#host.core.db.inbox==1,'lost ACK must retry without duplicating the inbox')
assert(host.core.db.inbox[1].player=='Friend-Realm')
assert(host.core.db.inbox[1].quantity==2)
assert(friend.draws==0,'ordinary guild members must never draw a marker')
assert(host.draws>0)
host.online=false
tick(100)
now=now+86400
friend.core:levelUp(20)
friend.core:levelUp(20)
friend.core:levelUp(21)
assert(#friend.core.db.own==2,'only one level-20 milestone')
now=now+86400
-- Simulate a fresh relay session with its persisted inbox and cursors.
host=make('Host-Realm','Player-1-HOST',host.core.db)
host.core:setRelay(true)
tick(55)
assert(#host.core.db.inbox==2,'offline level-up should sync on return')
assert(host.core.db.inbox[2].kind=='level' and host.core.db.inbox[2].level==20)
assert(host.core.db.inbox[2].timestamp==1780086400,'sync must preserve original event time')
-- Replay and reconnect cannot create a second copy.
friend=make('Friend-Realm','Player-1-FRIEND',friend.core.db)
tick(60)
assert(#host.core.db.inbox==2)
local malicious=LootBotProtocol.wire(friend.core.db.own[1])
host.core:receive(malicious,'WHISPER','Outsider-Realm')
assert(#host.core.db.inbox==2,'non-guild senders are rejected')
host.core:receive('E\tbad\tlevel\tnan','WHISPER','Friend-Realm')
assert(#host.core.db.inbox==2,'malformed events are rejected')
assert(not LootBotProtocol.parseWire(malicious,'Friend-Realm',now+31*86400),'expired history rejected')
local backup=make('Backup-Realm','Player-1-BACKUP')
backup.core:setRelay(true)
tick(60)
assert(#backup.core.db.inbox==2,'second relay receives retained events independently')
friend.core:record({kind='loot',itemId=456,quality=3,quantity=1,itemName='Blue item'})
tick(45)
assert(#host.core.db.inbox==3 and #backup.core.db.inbox==3,'both relays receive the same new event')
host.online=false
friend.core:levelUp(30)
tick(45)
assert(#backup.core.db.inbox==4 and backup.draws>0,'remaining relay continues while first relay is offline')
assert(friend.draws==0,'member remains invisible with multiple relays')
