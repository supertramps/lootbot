'use strict';
const assert = require('assert').strict;
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const { EventEmitter } = require('events');
const { adler32, decodePacket, encodePacket, qualifies, discordPayload, validateWebhook, validateSettings, EventTracker } = require('../companion/protocol');
const { post, deliver } = require('../companion/discord');
const { History, digestPayload } = require('../companion/history');
const tests = [];
const test = (name, fn) => tests.push([name, fn]);
const NOW = 1780000000;
const values = ['1780000000-1-123-1', 'Alex-TestRealm', 19019, 5, 1, 'Test Sword', NOW, false];
const event = decodePacket(encodePacket(values), NOW);

test('UTF-8 roundtrip and checksum rejects corruption', () => {
  const localized = [...values]; localized[1] = 'Ålex-TestRealm'; localized[5] = 'Épée du héros';
  assert.equal(decodePacket(encodePacket(localized), NOW).itemName, localized[5]);
  for (let i = 0; i < 6 + Buffer.byteLength(JSON.stringify(localized)) + 4; i++) {
    const bad = encodePacket(localized); bad[i] ^= 1;
    assert.equal(decodePacket(bad, NOW), null, `Corrupted byte ${i} accepted`);
  }
});
test('invalid fields, old events and oversized frames are rejected', () => {
  assert.equal(decodePacket(encodePacket(values), NOW + 31*86400), null);
  assert.equal(decodePacket(Buffer.alloc(200), NOW), null);
  for (const [index, value] of [[0, 'bad id'], [1, ''], [2, -1], [3, 99], [4, 0], [6, 'now'], [7, 'yes']]) {
    const input = [...values]; input[index] = value;
    assert.equal(decodePacket(encodePacket(input), NOW), null);
  }
});
test('quality filters, watch list and explicit test events', () => {
  const settings = validateSettings({ minimumQuality: 4, watchItemIds: [123] });
  assert(qualifies(event, settings));
  assert(!qualifies({ ...event, quality: 1 }, settings));
  assert(qualifies({ ...event, quality: 1, itemId: 123 }, settings));
  assert(qualifies({ ...event, quality: 1, test: true }, settings));
  assert(!qualifies({ ...event, itemId: 0, test: true }, settings));
  assert.throws(() => validateSettings({ pollMs: 1 }));
  assert.throws(() => validateSettings({ watchItemIds: ['123'] }));
});
test('repeated frames suppressed; separate identical loot drops retained', () => {
  const tracker = new EventTracker();
  assert(tracker.firstObservation(event));
  for (let i = 0; i < 100; i++) assert(!tracker.firstObservation(event));
  assert(tracker.firstObservation({ ...event, id: event.id + '-2' }));
  assert(tracker.firstObservation({ ...event, player: 'Another-Realm' }));
});
test('Discord payload labels tests and disables mentions', () => {
  const payload = discordPayload({ ...event, test: true, player: '@everyone_*' });
  assert.deepEqual(payload.allowed_mentions, { parse: [] });
  assert(payload.embeds[0].title.startsWith('TEST'));
  assert(payload.embeds[0].description.includes('\\_\\*'));
});
test('webhook validation refuses other destinations and credential tricks', () => {
  assert.equal(validateWebhook('https://discord.com/api/webhooks/123/abc_DEF').search, '?wait=true');
  for (const url of ['http://discord.com/api/webhooks/123/abc', 'https://example.com/api/webhooks/123/abc',
    'https://discord.com.evil.example/api/webhooks/123/abc', 'https://user@discord.com/api/webhooks/123/abc',
    'https://discord.com/api/webhooks/123/abc?thread_id=5']) assert.throws(() => validateWebhook(url));
});
test('rate limits retry, ambiguous failures do not duplicate a post', async () => {
  let attempts = 0, waits = [];
  await deliver('unused', {}, async () => {
    if (++attempts < 3) throw Object.assign(new Error('rate limit'), { status: 429, retryAfter: 2 });
  }, async ms => waits.push(ms));
  assert.equal(attempts, 3); assert.deepEqual(waits, [2000, 2000]);
  attempts = 0;
  await assert.rejects(deliver('unused', {}, async () => { attempts++; throw new Error('timeout'); }));
  assert.equal(attempts, 1);
});
test('HTTP sender sends JSON, parses 429 and scrubs network errors', async () => {
  function mockRequest(status, response, networkError) {
    return (url, options, callback) => {
      assert.equal(options.method, 'POST');
      const req = new EventEmitter(); req.setTimeout = () => {};
      req.end = body => {
        assert.equal(JSON.parse(body).hello, 'world');
        process.nextTick(() => {
          if (networkError) { req.emit('error', new Error('secret token URL')); return; }
          const res = new EventEmitter(); res.statusCode = status; res.setEncoding = () => {};
          callback(res); res.emit('data', response); res.emit('end');
        });
      };
      return req;
    };
  }
  await post('unused', { hello: 'world' }, mockRequest(200, '{}'));
  await assert.rejects(post('unused', { hello: 'world' }, mockRequest(429, '{"retry_after":2.5}')),
    e => e.status === 429 && e.retryAfter === 2.5);
  await assert.rejects(post('unused', { hello: 'world' }, mockRequest(0, '', true)), e => !e.message.includes('secret'));
});

// Fengari executes the actual addon Lua against a deliberately small WoW API mock.
const { lua, lauxlib, lualib, to_luastring } = require('fengari');
function vm() {
  const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
  function run(source) {
    lua.lua_settop(L, 0);
    if (lauxlib.luaL_dostring(L, to_luastring(source)) !== lua.LUA_OK) throw new Error(lua.lua_tojsstring(L, -1));
  }
  run(fs.readFileSync(path.join(__dirname, '../addon/LootBot/Protocol.lua'), 'utf8'));
  run(fs.readFileSync(path.join(__dirname, '../addon/LootBot/Relay.lua'), 'utf8'));
  return { run, bytes: () => Buffer.from(lua.lua_tolstring(L, -1)), close: () => lua.lua_close(L) };
}
test('actual Lua encoder matches the Node decoder byte for byte', () => {
  const v = vm();
  v.run(`return LootBotProtocol.packet({ id='${values[0]}', player='Alex-TestRealm', itemId=19019, quality=5, quantity=1, itemName='Test Sword', timestamp=${NOW}, test=false })`);
  assert.deepEqual(v.bytes(), encodePacket([...values, 'loot', 0]));
  v.run(`return LootBotProtocol.packet({ id='1', player='Ålex-Realm', itemId=1, quality=1, quantity=2, itemName=string.rep('É',200), timestamp=${NOW}, test=false })`);
  assert.equal(decodePacket(v.bytes(), NOW).itemName, '');
  v.close();
});
test('localized loot templates match own loot only, including quantities', () => {
  const v = vm();
  v.run(`
    local P=LootBotProtocol
    assert(P.selfLoot('You receive loot: [Sword].', {'You receive loot: %s.'}) == 1)
    assert(P.selfLoot('You receive loot: [Cloth]x12.', {'You receive loot: %sx%d.'}) == 12)
    assert(P.selfLoot('Vous recevez : [Épée] x3.', {'Vous recevez : %1$s x%2$d.'}) == 3)
    assert(P.selfLoot('Other receives loot: [Sword].', {'You receive loot: %s.'}) == nil)
  `); v.close();
});
test('addon lifecycle, self-loot event and optical rendering work together', () => {
  const v = vm();
  v.run(fs.readFileSync(path.join(__dirname, 'wow-mock.lua'), 'utf8'));
  v.run(fs.readFileSync(path.join(__dirname, '../addon/LootBot/LootBot.lua'), 'utf8'));
  v.run(`LootBotDriver.scripts.OnEvent(LootBotDriver, 'PLAYER_LOGIN'); assert(not LootBotMarker.shown); assert(#LootBotMarker.textures==0); SlashCmdList.LOOTBOT('relay on'); SlashCmdList.LOOTBOT('test'); LootBotDriver.scripts.OnUpdate(LootBotDriver, 1); return ReadMarker()`);
  let decoded = decodePacket(v.bytes(), NOW);
  assert(decoded && decoded.test && decoded.player === 'Alex-TestRealm');
  v.run(`LootBotDriver.scripts.OnEvent(LootBotDriver, 'CHAT_MSG_LOOT', 'You receive loot: |cffa335ee|Hitem:123:0|h[Special Sword]|h|rx2.'); MockTime=4; LootBotDriver.scripts.OnUpdate(LootBotDriver, 1); return ReadMarker()`);
  decoded = decodePacket(v.bytes(), NOW);
  assert(decoded && !decoded.test && decoded.itemId === 123 && decoded.quantity === 2 && decoded.quality === 4);
  const previous = v.bytes();
  v.run(`LootBotDriver.scripts.OnEvent(LootBotDriver, 'CHAT_MSG_LOOT', 'Other receives loot: |cffa335ee|Hitem:999:0|h[Other Sword]|h|r.'); return ReadMarker()`);
  assert.deepEqual(v.bytes(), previous);
  v.run(`SlashCmdList.LOOTBOT('off'); assert(not LootBotMarker.shown); SlashCmdList.LOOTBOT('on'); for i=1,10 do MockTime=100+i*20; LootBotDriver.scripts.OnUpdate(LootBotDriver, 1) end; assert(not LootBotMarker.shown)`);
  v.close();
});
test('personal filters discard junk before relay traffic and lock to Epic at level 40', () => {
  const v=vm(); v.run(fs.readFileSync(path.join(__dirname,'wow-mock.lua'),'utf8'));
  v.run(fs.readFileSync(path.join(__dirname,'../addon/LootBot/LootBot.lua'),'utf8'));
  v.run(`
    MockLevel=20
    LootBotDriver.scripts.OnEvent(LootBotDriver,'PLAYER_LOGIN')
    local db=LootBotDB.characters[UnitGUID('player')]
    assert(db.personalQuality==3 and not db.epicLocked)
    LootBotDriver.scripts.OnEvent(LootBotDriver,'CHAT_MSG_LOOT','You receive loot: |cff1eff00|Hitem:11:0|h[Green]|h|r.')
    assert(#db.own==0)
    LootBotDriver.scripts.OnEvent(LootBotDriver,'CHAT_MSG_LOOT','You receive loot: |cff0070dd|Hitem:12:0|h[Blue]|h|r.')
    assert(#db.own==1 and db.own[1].quality==3)
    SlashCmdList.LOOTBOT('filter epic')
    assert(#db.own==0 and db.personalQuality==4)
    SlashCmdList.LOOTBOT('filter rare')
    LootBotDriver.scripts.OnEvent(LootBotDriver,'CHAT_MSG_LOOT','You receive loot: |cff0070dd|Hitem:13:0|h[Blue]|h|r.')
    assert(#db.own==1)
    LootBotDriver.scripts.OnEvent(LootBotDriver,'PLAYER_LEVEL_UP',40)
    assert(db.epicLocked and db.personalQuality==4 and #db.own==1 and db.own[1].kind=='level')
    SlashCmdList.LOOTBOT('filter rare')
    assert(db.personalQuality==4)
    LootBotDriver.scripts.OnEvent(LootBotDriver,'CHAT_MSG_LOOT','You receive loot: |cff0070dd|Hitem:14:0|h[Blue]|h|r.')
    assert(#db.own==1)
    LootBotDriver.scripts.OnEvent(LootBotDriver,'CHAT_MSG_LOOT','You receive loot: |cffa335ee|Hitem:15:0|h[Purple]|h|r.')
    assert(#db.own==2 and db.own[2].quality==4)
  `); v.close();
});
test('marker stays at physical pixel size across display resolutions and UI scales', () => {
  const v = vm();
  v.run(fs.readFileSync(path.join(__dirname, 'wow-mock.lua'), 'utf8'));
  v.run(fs.readFileSync(path.join(__dirname, '../addon/LootBot/LootBot.lua'), 'utf8'));
  v.run(`
    for _,height in ipairs({720,1080,1440,2160}) do
      for _,scale in ipairs({0.5,0.8,1,1.25}) do
        MockHeight=height; MockScale=scale
        LootBotDriver.scripts.OnEvent(LootBotDriver, 'DISPLAY_SIZE_CHANGED')
        local pixelsPerUnit=LootBotMarker.scale*scale*height/768
        assert(math.abs(LootBotMarker.width*pixelsPerUnit-128)<0.00001)
        assert(math.abs(LootBotMarker.height*pixelsPerUnit-16)<0.00001)
        assert(math.abs(LootBotMarker.x*pixelsPerUnit-16)<0.00001)
        assert(math.abs(LootBotMarker.y*pixelsPerUnit+16)<0.00001)
      end
    end
  `);
  v.close();
});
test('saved webhook roundtrip tolerates the newline written by Setup', () => {
  if (process.platform !== 'win32') { console.log('  Windows-only credential test skipped'); return; }
  const os = require('os');
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'LootBot-Credential-Test-'));
  const launcher = path.join(temporary, 'Start-LootBot.ps1');
  const secretPath = path.join(temporary, 'webhook.dpapi');
  const writer = path.join(temporary, 'write-dummy.ps1');
  const dummy = 'https://discord.com/api/webhooks/123/LootBotSyntheticTestOnly';
  const env = { ...process.env };
  for (const name of Object.keys(env)) if (name.toLowerCase() === 'psmodulepath') delete env[name];
  try {
    fs.copyFileSync(path.join(__dirname, '../Start-LootBot.ps1'), launcher);
    fs.writeFileSync(writer, `$ErrorActionPreference = 'Stop'\n$secret = ConvertTo-SecureString '${dummy}' -AsPlainText -Force\nConvertFrom-SecureString $secret | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'webhook.dpapi') -Encoding ASCII\n`);
    const saved = spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', writer],
      { encoding: 'utf8', windowsHide: true, timeout: 10000, env });
    assert.equal(saved.status, 0, 'Synthetic DPAPI setup failed; run this test under a normal Windows user profile.');
    assert(fs.readFileSync(secretPath, 'utf8').endsWith('\r\n'));
    const read = spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', launcher, '-Mode', 'ReadWebhook'],
      { encoding: 'utf8', windowsHide: true, timeout: 10000, env });
    assert.equal(read.status, 0, 'ReadWebhook failed on the synthetic saved credential.');
    assert.equal(read.stdout, dummy);
  } finally {
    for (const file of [writer, secretPath, launcher]) if (fs.existsSync(file)) fs.unlinkSync(file);
    fs.rmdirSync(temporary);
  }
});
test('Windows GDI decoder reads synthetic pixels and rejects ambiguous pixels', () => {
  if (process.platform !== 'win32') { console.log('  Windows-only pixel test skipped'); return; }
  const result = spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
    path.join(__dirname, '../companion/capture.ps1'), '-TestPacket', encodePacket(values).toString('base64')],
  { encoding: 'utf8', windowsHide: true, timeout: 30000 });
  assert.equal(result.status, 0, result.stderr || result.error?.message);
  assert.deepEqual(Buffer.from(result.stdout.trim(), 'base64'), encodePacket(values));
});
test('tray credential storage is compatible with the helper reader', () => {
  if(process.platform!=='win32') return;
  const os=require('os');const dir=fs.mkdtempSync(path.join(os.tmpdir(),'LootBot-Tray-Test-'));
  const secret=path.join(dir,'webhook.dpapi');const launcher=path.join(dir,'Start-LootBot.ps1');
  const env={...process.env};for(const k of Object.keys(env)) if(k.toLowerCase()==='psmodulepath') delete env[k];
  try {
    fs.copyFileSync(path.join(__dirname,'../Start-LootBot.ps1'),launcher);
    const saved=spawnSync(path.join(__dirname,'../LootBot.exe'),['--test-save',secret],{windowsHide:true,timeout:10000});
    assert.equal(saved.status,0,'Tray test credential write failed');
    const read=spawnSync('powershell.exe',['-NoProfile','-ExecutionPolicy','Bypass','-File',launcher,'-Mode','ReadWebhook'],{encoding:'utf8',windowsHide:true,env,timeout:10000});
    assert.equal(read.status,0);assert.equal(read.stdout,'https://discord.com/api/webhooks/123/LootBotSyntheticTestOnly');
  } finally {for(const f of [secret,launcher]) if(fs.existsSync(f))fs.unlinkSync(f);fs.rmdirSync(dir);}
});

test('two-addon simulation: offline sync, lost ACK, dedupe, member invisibility and sender checks', () => {
  const v=vm(); v.run(fs.readFileSync(path.join(__dirname,'relay-simulation.lua'),'utf8')); v.close();
});
test('level milestones use the event value, persist, and never announce the login level', () => {
  const v=vm(); v.run(fs.readFileSync(path.join(__dirname,'wow-mock.lua'),'utf8'));
  v.run(fs.readFileSync(path.join(__dirname,'../addon/LootBot/LootBot.lua'),'utf8'));
  v.run(`
    LootBotDriver.scripts.OnEvent(LootBotDriver,'PLAYER_LOGIN')
    local db=LootBotDB.characters[UnitGUID('player')]
    assert(#db.own==0)
    LootBotDriver.scripts.OnEvent(LootBotDriver,'PLAYER_LEVEL_UP',10)
    LootBotDriver.scripts.OnEvent(LootBotDriver,'PLAYER_LEVEL_UP',10)
    LootBotDriver.scripts.OnEvent(LootBotDriver,'PLAYER_LEVEL_UP',11)
    LootBotDriver.scripts.OnEvent(LootBotDriver,'PLAYER_LEVEL_UP',20)
    assert(#db.own==2 and db.own[1].level==10 and db.own[2].level==20)
    assert(not LootBotMarker.shown and #LootBotMarker.textures==0)
    return LootBotProtocol.packet(db.own[1])
  `);
  const e=decodePacket(v.bytes(),NOW);
  assert(e && e.kind==='level' && e.level===10);
  assert(qualifies(e,validateSettings({minimumQuality:8})));
  assert(!qualifies(e,validateSettings({levelMilestones:[20]})));
  assert(discordPayload(e).embeds[0].description.includes('level 10'));
  v.close();
});
test('old events form one catch-up digest, new events stay live, late sync is batched', () => {
  const settings=validateSettings({}); const h=new History(null,settings,NOW);
  assert(h.receive({...event,id:'old-1',timestamp:NOW-86400},NOW));
  assert(!h.receive({...event,id:'old-1',timestamp:NOW-86400},NOW));
  h.receive({...event,id:'old-2',kind:'level',itemId:0,level:20,timestamp:NOW-80000},NOW+1);
  assert.equal(h.next(NOW+100),null);
  h.receive({...event,id:'live-1',timestamp:NOW+100},NOW+100);
  let b=h.next(NOW+100); assert(!b.digest && b.keys.length===1);h.begin(b);h.finish(b,true,NOW+100);
  b=h.next(NOW+121);assert(b.digest && b.keys.length===2);h.begin(b);h.finish(b,true,NOW+121);
  assert.equal(h.next(NOW+122),null);
  h.receive({...event,id:'late-1',timestamp:NOW-70000},NOW+200);
  assert.equal(h.next(NOW+400),null);
  assert(h.next(NOW+1022).digest);
});
test('delivery history survives restart and holds uncertain deliveries instead of reposting', () => {
  const os=require('os'); const dir=fs.mkdtempSync(path.join(os.tmpdir(),'LootBot-History-Test-'));
  const file=path.join(dir,'history.json'); const settings=validateSettings({});
  try {
    let h=new History(file,settings,NOW);h.receive(event,NOW);let b=h.next(NOW);h.begin(b);h.finish(b,true,NOW);
    h=new History(file,settings,NOW+10);assert(!h.receive(event,NOW+10));assert.equal(h.next(NOW+1000),null);
    h.receive({...event,id:'crash-1',timestamp:NOW+10},NOW+10);b=h.next(NOW+10);h.begin(b);
    h=new History(file,settings,NOW+20);assert.equal(h.uncertainCount(),1);assert.equal(h.next(NOW+1000),null);
  } finally { for(const p of [file,file+'.tmp']) if(fs.existsSync(p))fs.unlinkSync(p);fs.rmdirSync(dir); }
});
test('large digest stays within Discord limits with explicit totals and Wowhead links', () => {
  const events=Array.from({length:400},(_,i)=>({...event,id:'many-'+i,player:'Friend'+(i%20)+'-Realm',itemName:'A very long special item name '.repeat(3)}));
  const p=digestPayload(events);assert(p.embeds[0].description.length<=4096);
  assert(p.embeds[0].description.includes('400 loot events'));
  assert(p.embeds[0].description.includes('https://www.wowhead.com/classic/item='));
  assert.deepEqual(p.allowed_mentions,{parse:[]});
});

(async () => {
  let failures = 0;
  for (const [name, fn] of tests) {
    try { await fn(); console.log(`PASS ${name}`); }
    catch (error) { failures++; console.error(`FAIL ${name}\n${error.stack}`); }
  }
  console.log(`\n${tests.length - failures}/${tests.length} tests passed. No Discord requests or desktop captures were performed.`);
  process.exitCode = failures ? 1 : 0;
})();
