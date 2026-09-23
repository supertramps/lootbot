// LootBot shared delivery service. No request bodies or credentials are logged.
import {titleFor,itemInfo} from './style.mjs';
export const schema = [
`CREATE TABLE IF NOT EXISTS events (id TEXT PRIMARY KEY, body TEXT NOT NULL, received INTEGER NOT NULL, backlog INTEGER NOT NULL, state TEXT NOT NULL DEFAULT 'pending', batch TEXT)`,
`CREATE INDEX IF NOT EXISTS pending_events ON events(state, backlog, received)`,
`CREATE TABLE IF NOT EXISTS control (id INTEGER PRIMARY KEY, owner TEXT, lease INTEGER NOT NULL DEFAULT 0, last_digest INTEGER NOT NULL DEFAULT 0, next_send INTEGER NOT NULL DEFAULT 0)`,
`INSERT OR IGNORE INTO control(id) VALUES(1)`,
`CREATE TABLE IF NOT EXISTS relays (id TEXT PRIMARY KEY, jwk TEXT NOT NULL, enabled INTEGER NOT NULL DEFAULT 1, admin INTEGER NOT NULL DEFAULT 0)`,
`CREATE TABLE IF NOT EXISTS settings (id INTEGER PRIMARY KEY, body TEXT NOT NULL)`,
`INSERT OR IGNORE INTO settings(id,body) VALUES(1,'{"minimumQuality":0,"watchItemIds":[],"blockedItemIds":[]}')`,
`CREATE TABLE IF NOT EXISTS items (id INTEGER PRIMARY KEY, body TEXT NOT NULL, updated INTEGER NOT NULL)`];
const json=(value,status=200)=>Response.json(value,{status,headers:{'Cache-Control':'no-store'}});
const now=()=>Math.floor(Date.now()/1000);
const esc=s=>s.replace(/([\\`*_{}\[\]()<>~|])/g,'\\$1');
const displayName=name=>name.split('-')[0]||name;
const shownPlayer=e=>e.test?'LootTester':displayName(e.player);
function levelCard(e) {
  const player=esc(shownPlayer(e));
  const milestones={
    10:{title:'Level 10',color:0x67b883,description:`**${player}** hit **level 10**. Nice!`},
    20:{title:'Level 20 ✨',color:0x5aace8,description:`**${player}** hit **level 20**. Grats!`},
    30:{title:'Level 30 ⚔️',color:0x9674dc,description:`**${player}** hit **level 30**. Halfway there.`},
    40:{title:'Level 40 🔥',color:0xe17d49,description:`**${player}** hit **level 40**. Nice one!`},
    50:{title:'Level 50 🎉',color:0xf2b447,description:`**${player}** hit **level 50**. Ten to go!`},
    60:{title:'Level 60 🏆',color:0xffd700,description:`**Max level.** Huge grats, ${player}!\nMaybe it's time to touch some grass?`,content:`🎉 ${player} dinged 60!`}
  };
  return milestones[e.level]||{title:`✨ Level ${e.level}! ✨`,color:0xffd166,description:`**${player}** reached **level ${e.level}**!`};
}
export function validate(e,t=now()) {
  if(!e || typeof e!=='object' || typeof e.id!=='string' || !/^[A-Za-z0-9-]{1,100}$/.test(e.id) ||
    typeof e.player!=='string' || !e.player || e.player.length>120 || typeof e.itemName!=='string' || e.itemName.length>160 ||
    typeof e.test!=='boolean' || !Number.isInteger(e.timestamp) || e.timestamp<t-30*86400 || e.timestamp>t+120 ||
    !Number.isInteger(e.itemId) || e.itemId<0 || e.itemId>10000000 || !Number.isInteger(e.quality) || e.quality< -1 || e.quality>8 ||
    !Number.isInteger(e.quantity) || e.quantity<0 || e.quantity>1000000 || !Number.isInteger(e.level)) return false;
  return e.kind==='loot' ? e.itemId>0 && e.quantity>0 && e.level===0 : e.kind==='level' && e.itemId===0 && e.level>=10 && e.level<=200 && e.level%10===0;
}
export function payload(rows,digest,botName='LootBot') {
  const es=rows.map(r=>JSON.parse(r.body));
  const item=e=>`[${esc(e.itemName||'Item #'+e.itemId)}](https://www.wowhead.com/classic/item=${e.itemId}) ×${e.quantity}`;
  let description='', title, color=0x79d9a6,content;
  if(digest) {
    title='Guild catch-up'; const players=new Map();
    for(const e of es) { const name=shownPlayer(e);if(!players.has(name))players.set(name,[]); players.get(name).push(e); }
    description=`**${es.length} events from ${players.size} players**\n`;
    for(const [name,list] of players) {
      list.sort((a,b)=>a.kind==='level'&&b.kind!=='level'?-1:b.kind==='level'&&a.kind!=='level'?1:
        a.kind==='level'?b.level-a.level:b.quality-a.quality);
      const line=`\n**${esc(name)}**: `+list.map(e=>(e.kind==='level'?'level '+e.level:item(e))).join('; ');
      description+=line;
    }
  } else {
    const e=es[0];
    if(e.kind==='level')({title,description,color,content}=levelCard(e));
    else {title=titleFor(e);description=`**${esc(shownPlayer(e))}** received ${item(e)}.`;color=[0x9d9d9d,0xffffff,0x1eff00,0x0070dd,0xa335ee,0xff8000][e.quality]||color;}
  }
  return {username:botName,allowed_mentions:{parse:[]},...(content?{content}:{}),embeds:[{title,description,color,
    ...(digest?{}:{timestamp:new Date(es[0].timestamp*1000).toISOString()})}]};
}
function sampleDigest(id,t) {
  const source=[
    ['LootTester-ExampleRealm','level',20,0,'',0],
    ['LootTester-ExampleRealm','loot',0,19019,'Thunderfury, Blessed Blade of the Windseeker',5],
    ['LootTester-ExampleRealm','loot',0,755,'Melted Candle',0],
    ['LootTesterTwo-ExampleRealm','level',30,0,'',0],
    ['LootTesterTwo-ExampleRealm','loot',0,6948,'Hearthstone',1],
    ['LootTesterTwo-ExampleRealm','level',40,0,'',0],
    ['LootTesterThree-ExampleRealm','loot',0,755,'Melted Candle',0],
    ['LootTesterThree-ExampleRealm','level',50,0,'',0],
    ['LootTesterThree-ExampleRealm','loot',0,6948,'Hearthstone',1]
  ];
  return source.map(([player,kind,level,itemId,itemName,quality],i)=>({id:`${id}-${i}`,player,kind,level,itemId,itemName,quality,quantity:1,timestamp:t-86400,test:false}));
}
export async function init(db) { await db.batch(schema.map(s=>db.prepare(s))); }
async function authorized(request,body,db) {
  const id=request.headers.get('X-LootBot-Relay')||'', stamp=request.headers.get('X-LootBot-Time')||'';
  if(!/^[a-f0-9]{32}$/.test(id)||!/^\d{10}$/.test(stamp)||Math.abs(now()-Number(stamp))>120)return false;
  const relay=await db.prepare('SELECT jwk,admin FROM relays WHERE id=? AND enabled=1').bind(id).first();
  if(!relay)return false;
  try {
    const key=await crypto.subtle.importKey('jwk',JSON.parse(relay.jwk),{name:'ECDSA',namedCurve:'P-256'},false,['verify']);
    const signature=Uint8Array.from(atob(request.headers.get('X-LootBot-Signature')||''),c=>c.charCodeAt(0));
    return await crypto.subtle.verify({name:'ECDSA',hash:'SHA-256'},key,signature,new TextEncoder().encode(stamp+'\n'+new URL(request.url).pathname+'\n'+body))?relay:false;
  } catch { return false; }
}
export async function accept(db,events,t=now(),imported=false) {
  const settings=await getSettings(db);
  await db.batch(events.map(e=>db.prepare('INSERT OR IGNORE INTO events(id,body,received,backlog,state) VALUES(?,?,?,?,?)')
    .bind(e.player+':'+e.id,JSON.stringify(e),t,e.timestamp<t-90?1:0,imported?'sent':allowed(e,settings)?'pending':'filtered')));
}
async function getSettings(db){return {botName:'LootBot',...JSON.parse((await db.prepare('SELECT body FROM settings WHERE id=1').first()).body)};}
function validSettings(s){return s&&typeof s.botName==='string'&&s.botName.trim()===s.botName&&s.botName.length>=1&&s.botName.length<=80&&!/[\r\n]/.test(s.botName)&&Number.isInteger(s.minimumQuality)&&s.minimumQuality>=0&&s.minimumQuality<=8&&['watchItemIds','blockedItemIds'].every(k=>Array.isArray(s[k])&&s[k].length<=500&&s[k].every(n=>Number.isInteger(n)&&n>0&&n<=10000000));}
// Personal filters are enforced by the originating addon. The cloud keeps a
// hard Rare floor for mixed-version protection and a shared explicit blocklist.
function allowed(e,s){return e.test||e.kind==='level'||(e.quality>=3&&!s.blockedItemIds.includes(e.itemId));}
async function decorated(rows,digest,db) {
 const synthetic=rows.length===1&&JSON.parse(rows[0].body).kind==='digest';
 if(synthetic){rows=JSON.parse(rows[0].body).sample.map(e=>({body:JSON.stringify(e)}));digest=true;}
 const result=payload(rows,digest,(await getSettings(db)).botName);
 if(!digest){const e=JSON.parse(rows[0].body);if(e.kind==='loot')try{result.embeds[0].thumbnail={url:(await itemInfo(e.itemId,db)).icon};}catch{}}
 return result;
}
export async function dispatch(env,send=fetch,t=now()) {
  if(!env.DISCORD_WEBHOOK)return;
  let url;
  try { url=new URL(env.DISCORD_WEBHOOK); if(url.protocol!=='https:'||url.hostname!=='discord.com'||url.port||url.username||url.password||!/^\/api(?:\/v\d+)?\/webhooks\/\d+\/[A-Za-z0-9_-]+$/.test(url.pathname)||url.search||url.hash)return; } catch{return;}
  url.searchParams.set('wait','true');
  const db=env.DB, owner=crypto.randomUUID();
  if(!await db.prepare("SELECT id FROM events WHERE state IN ('pending','sending') LIMIT 1").first())return;
  const lock=await db.prepare('UPDATE control SET owner=?,lease=? WHERE id=1 AND lease<? AND next_send<=?').bind(owner,t+180,t,t).run();
  if(!lock.meta.changes)return;
  try {
    // A previous send may have succeeded before its process stopped. Never blindly resend it.
    await db.prepare("UPDATE events SET state='uncertain' WHERE state='sending'").run();
    await db.prepare("UPDATE events SET backlog=1 WHERE state='pending' AND backlog=0 AND received<?").bind(t-90).run();
    const settings=await getSettings(db);
    await db.prepare("UPDATE events SET state='filtered' WHERE state='pending' AND json_extract(body,'$.test')=0 AND json_extract(body,'$.kind')='loot' AND (json_extract(body,'$.itemId') IN (SELECT value FROM json_each(?)) OR json_extract(body,'$.quality')<3)").bind(JSON.stringify(settings.blockedItemIds)).run();
    let rows=(await db.prepare("SELECT * FROM events WHERE state='pending' AND backlog=0 ORDER BY received LIMIT 1").all()).results;
    let digest=false,special=false;
    if(!rows.length) {
      rows=(await db.prepare("SELECT * FROM events WHERE state='pending' AND backlog=1 AND (json_extract(body,'$.kind')='digest' OR (json_extract(body,'$.kind')='level' AND json_extract(body,'$.level')=60)) ORDER BY received LIMIT 1").all()).results;
      if(rows.length)special=true;
      else {
        const first=await db.prepare("SELECT MIN(received) AS oldest FROM events WHERE state='pending' AND backlog=1").first();
        const ctl=await db.prepare('SELECT last_digest FROM control WHERE id=1').first();
        if(first.oldest===null||t<Math.max(first.oldest+120,ctl.last_digest+900))return;
        rows=(await db.prepare("SELECT * FROM events WHERE state='pending' AND backlog=1 ORDER BY received LIMIT 40").all()).results; digest=true;
        let low=1,high=rows.length;
        while(low<high){const mid=Math.ceil((low+high)/2);if(payload(rows.slice(0,mid),true).embeds[0].description.length<=3700)low=mid;else high=mid-1;}
        rows=rows.slice(0,low);
      }
    }
    if(!rows.length)return;
    const batch=crypto.randomUUID();
    if(digest){
      const ids=rows.map(r=>r.id);
      const claimed=(await db.prepare(`UPDATE events SET state='sending',batch=? WHERE state='pending' AND id IN (${ids.map(()=>'?').join(',')}) RETURNING *`).bind(batch,...ids).all()).results;
      const byId=new Map(claimed.map(r=>[r.id,r]));rows=ids.map(id=>byId.get(id)).filter(Boolean);
    }else rows=special?(await db.prepare("UPDATE events SET state='sending',batch=? WHERE id=? AND state='pending' RETURNING *").bind(batch,rows[0].id).all()).results:
      (await db.prepare("UPDATE events SET state='sending',batch=? WHERE id IN (SELECT id FROM events WHERE state='pending' AND backlog=0 ORDER BY received LIMIT 1) RETURNING *").bind(batch).all()).results;
    if(!rows.length)return;
    const message=await decorated(rows,digest,db);
    let state='uncertain',retry=0;
    try {
      const response=await send(url.toString(),{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(message),signal:AbortSignal.timeout(10000)});
      if(response.ok)state='sent';
      else if(response.status===429) {state='pending'; const data=await response.json().catch(()=>({}));retry=Math.max(1,Math.min(3600,Number(data.retry_after)||5));}
    }catch{} // timeout is ambiguous; preserve for review
    const updates=[db.prepare("UPDATE events SET state=? WHERE batch=? AND state='sending'").bind(state,batch),
      db.prepare('UPDATE control SET next_send=? WHERE id=1 AND owner=?').bind(t+Math.max(retry,2),owner)];
    if(digest&&state==='sent')updates.push(db.prepare('UPDATE control SET last_digest=? WHERE id=1 AND owner=?').bind(t,owner));
    await db.batch(updates);
  } finally { await db.prepare('UPDATE control SET lease=0,owner=NULL WHERE id=1 AND owner=?').bind(owner).run(); }
}
export default {
  async fetch(request,env,ctx) {
    try {
      const path=new URL(request.url).pathname;
      if(request.method==='GET'&&path==='/health') {await env.DB.prepare('SELECT 1').first();return json({service:'LootBot',version:'0.3.0',database:true,discordConfigured:!!env.DISCORD_WEBHOOK});}
      if(request.method!=='POST'||!['/events','/import-delivered','/status','/settings','/preview','/test','/pulse','/relays'].includes(path))return json({error:'Not found'},404);
      if(Number(request.headers.get('Content-Length'))>65536)return json({error:'Too large'},413);
      const reader=request.body?.getReader(); let parts=[],size=0;
      if(!reader)return json({error:'Body required'},400);
      while(true){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>65536){await reader.cancel();return json({error:'Too large'},413);}parts.push(value);}
      const bytes=new Uint8Array(size);let offset=0;for(const p of parts){bytes.set(p,offset);offset+=p.length;}const body=new TextDecoder('utf-8',{fatal:true}).decode(bytes);
      const relay=await authorized(request,body,env.DB);
      if(!relay)return json({error:'Relay not registered or signature invalid'},401);
      if(path==='/pulse'){ctx.waitUntil(dispatch(env));return json({ok:true});}
      if(path==='/status')return json({counts:(await env.DB.prepare('SELECT state,COUNT(*) AS count FROM events GROUP BY state').all()).results,discordConfigured:!!env.DISCORD_WEBHOOK});
      if(path==='/import-delivered'&&(env.ALLOW_IMPORT!=='yes'||!relay.admin))return json({error:'Import disabled'},403);
      const data=JSON.parse(body);
      if(path==='/relays'){
        if(!relay.admin)return json({error:'Only the guild administrator can manage relays'},403);
        if(data.registration){
          const r=data.registration;if(!r||!r.publicKey||typeof r.id!=='string'||!/^[a-f0-9]{32}$/.test(r.id))return json({error:'Invalid relay registration'},400);
          const k=r.publicKey;if(k.kty!=='EC'||k.crv!=='P-256'||typeof k.x!=='string'||typeof k.y!=='string'||!/^[-_A-Za-z0-9]{43}$/.test(k.x)||!/^[-_A-Za-z0-9]{43}$/.test(k.y))return json({error:'Invalid public key'},400);
          const jwk={kty:k.kty,crv:k.crv,x:k.x,y:k.y};try{await crypto.subtle.importKey('jwk',jwk,{name:'ECDSA',namedCurve:'P-256'},false,['verify']);}catch{return json({error:'Invalid public key'},400);}
          if((await env.DB.prepare('SELECT COUNT(*) AS n FROM relays').first()).n>=20)return json({error:'Relay limit reached'},400);
          await env.DB.prepare('INSERT OR IGNORE INTO relays(id,jwk) VALUES(?,?)').bind(r.id,JSON.stringify(jwk)).run();
        }
        if(data.revoke){if(data.revoke===request.headers.get('X-LootBot-Relay'))return json({error:'Cannot revoke your own administrator identity'},400);await env.DB.prepare('UPDATE relays SET enabled=0 WHERE id=? AND admin=0').bind(data.revoke).run();}
        return json({relays:(await env.DB.prepare('SELECT id,enabled,admin FROM relays').all()).results});
      }
      if(path==='/settings'){
        if(data.settings){if(!relay.admin)return json({error:'Only the guild administrator can change filters'},403);if(!validSettings(data.settings))return json({error:'Invalid filters'},400);await env.DB.prepare('UPDATE settings SET body=? WHERE id=1').bind(JSON.stringify(data.settings)).run();}
        return json(await getSettings(env.DB));
      }
      if(path==='/preview'||path==='/test'){
        if(!relay.admin)return json({error:'Only the guild administrator can send tests'},403);
        if(data.kind==='digest'){
          const id=typeof data.id==='string'?data.id:crypto.randomUUID();
          if(!/^[A-Za-z0-9-]{1,100}$/.test(id))return json({error:'Invalid test ID'},400);
          const sample=sampleDigest(id,now());
          const message=payload(sample.map(e=>({body:JSON.stringify(e)})),true,(await getSettings(env.DB)).botName);
          if(path==='/test'){
            if(!env.DISCORD_WEBHOOK)return json({error:'Discord is not configured yet'},409);
            await env.DB.prepare("INSERT OR IGNORE INTO events(id,body,received,backlog,state) VALUES(?,?,?,0,'pending')").bind('test-digest:'+id,JSON.stringify({kind:'digest',sample}),now()).run();
            ctx.waitUntil(dispatch(env));
          }
          return json({payload:message,queued:path==='/test'});
        }
        const e={id:typeof data.id==='string'?data.id:crypto.randomUUID(),player:'LootTester-ExampleRealm',itemId:0,quality:0,quantity:1,itemName:'',timestamp:now(),test:true,kind:data.kind,level:0};
        if(data.kind==='loot') {let info;try{info=await itemInfo(data.itemId,env.DB);}catch{return json({error:'Could not find that Classic item on Wowhead'},400);}e.itemId=data.itemId;e.itemName=info.name;e.quality=info.quality;}
        else {e.level=data.level;}
        if(!validate(e))return json({error:'Use an item ID or a milestone level: 10, 20, 30, etc.'},400);
        const message=await decorated([{body:JSON.stringify(e)}],false,env.DB);
        if(path==='/test'){if(!env.DISCORD_WEBHOOK)return json({error:'Discord is not configured yet'},409);await accept(env.DB,[e]);ctx.waitUntil(dispatch(env));}
        return json({payload:message,queued:path==='/test'});
      }
      if(!Array.isArray(data.events)||data.events.length<1||data.events.length>20||!data.events.every(e=>validate(e)))return json({error:'Invalid events'},400);
      await accept(env.DB,data.events,now(),path==='/import-delivered');ctx.waitUntil(dispatch(env));return json({accepted:true,count:data.events.length});
    } catch {return json({error:'Service unavailable; relay should retry'},503);}
  },
  async scheduled(event,env,ctx) {ctx.waitUntil((async()=>{await dispatch(env);await env.DB.prepare("DELETE FROM events WHERE id IN (SELECT id FROM events WHERE state IN ('sent','filtered') AND received<? LIMIT 500)").bind(now()-31*86400).run();})());}
};
