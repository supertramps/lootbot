'use strict';
const fs = require('fs');
const path = require('path');
const readline = require('readline');
const { spawn, spawnSync } = require('child_process');
const { decodePacket, qualifies, validateWebhook, validateSettings, EventTracker } = require('./protocol');
const { History } = require('./history');
const { deliver } = require('./discord');
const { identity, endpoint, CloudQueue } = require('./cloud');
const ROOT = path.resolve(__dirname, '..');
const args = new Set(process.argv.slice(2));
const powershellEnv = { ...process.env };
for (const name of Object.keys(powershellEnv)) if (name.toLowerCase() === 'psmodulepath') delete powershellEnv[name];
async function main() {
  if ([...args].some(a => !['--send', '--all'].includes(a))) throw new Error('Usage: node companion/main.js [--send] [--all]');
  const settingsPath = path.join(ROOT, 'settings.json');
  const settings = validateSettings(fs.existsSync(settingsPath) ? JSON.parse(fs.readFileSync(settingsPath, 'utf8').replace(/^\uFEFF/, '')) : {});
  if (args.has('--all')) settings.minimumQuality = 0;
  const sending = args.has('--send');
  const cloudFile = path.join(ROOT, 'cloud-config.json');
  const cloudConfig = fs.existsSync(cloudFile) ? JSON.parse(fs.readFileSync(cloudFile, 'utf8')) : null;
  if (cloudConfig) cloudConfig.url = endpoint(cloudConfig.url);
  let webhook;
  if (sending && !cloudConfig) {
    let raw = process.env.LOOTBOT_WEBHOOK_URL;
    if (!raw) {
      const result = spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
        path.join(ROOT, 'Start-LootBot.ps1'), '-Mode', 'ReadWebhook'], { encoding: 'utf8', windowsHide: true, env: powershellEnv });
      if (result.status !== 0) throw new Error('No readable webhook configured. Use the tray menu to configure Discord.');
      raw = result.stdout.trim();
    }
    webhook = validateWebhook(raw);
  }
  const stateDir = path.join(ROOT, 'state');
  fs.mkdirSync(stateDir, { recursive: true });
  const lockPath = path.join(stateDir, 'running.lock');
  try { fs.writeFileSync(lockPath, String(process.pid), { flag: 'wx' }); }
  catch (error) {
    if (error.code !== 'EEXIST') throw error;
    const pid = Number(fs.readFileSync(lockPath, 'utf8'));
    let alive = false;
    try { if (pid > 0) { process.kill(pid, 0); alive = true; } }
    catch (e) { if (e.code !== 'ESRCH') alive = true; }
    if (alive) throw new Error('LootBot is already running. Close the old helper first.');
    fs.unlinkSync(lockPath); fs.writeFileSync(lockPath, String(process.pid), { flag: 'wx' });
  }
  process.on('exit', () => { try { fs.unlinkSync(lockPath); } catch (_) {} });
  const oldFile = path.join(stateDir, 'delivered.json');
  const legacy = sending && fs.existsSync(oldFile) ? JSON.parse(fs.readFileSync(oldFile, 'utf8')) : {};
  const history = new History(sending ? path.join(stateDir, 'history.json') : null, settings, Date.now() / 1000, legacy);
  if (history.uncertainCount()) console.error(history.uncertainCount() + ' event(s) have uncertain delivery; inspect state/history.json before retrying.');
  const seen = new EventTracker();
  const cloud = sending && cloudConfig ? new CloudQueue(path.join(stateDir, 'cloud-queue.json'),cloudConfig,identity()) : null;
  let lastStatus = '', lastFrame = '', busy = false, stopping = false;
  function status(message) { if (message !== lastStatus) { console.log(message); lastStatus = message; } }
  console.log(sending ? 'LootBot LIVE — loot and level milestones will post to Discord.' : 'LootBot PREVIEW — no Discord messages will be sent.');
  if (cloud) console.log('Shared relay service enabled. Multiple relays use one Discord delivery history.');
  console.log('Quality ' + settings.minimumQuality + '+; catch-up after ' + settings.digestDelaySeconds + 's, then at most once per ' + settings.digestCooldownSeconds + 's.');
  console.log('Relay: /lootbot relay on. If starting after login, use /lootbot sync to replay saved records.');
  const child = spawn('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
    path.join(__dirname, 'capture.ps1'), '-X', String(settings.markerX), '-Y', String(settings.markerY),
    '-Cell', String(settings.cellSize), '-PollMs', String(settings.pollMs), '-TargetPid', String(settings.processId)],
    { windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'], env: powershellEnv });
  const input = readline.createInterface({ input: process.stdin });
  let timer;
  function shutdown() {
    if (stopping) return;
    stopping = true; clearInterval(timer); child.kill(); input.close(); process.stdin.pause();
  }
  input.on('line', line => { if (line.trim() === 'stop') shutdown(); });
  process.on('SIGINT', shutdown); process.on('SIGTERM', shutdown);
  child.on('error', () => { console.error('Could not start Windows capture helper.'); shutdown(); process.exitCode = 1; });
  child.stderr.on('data', () => status('Capture helper error. Check Windows desktop availability or run the tests.'));
  child.on('exit', code => { if (!stopping) { shutdown(); console.error('Capture helper stopped (' + code + ').'); process.exitCode = 1; } });
  async function flush() {
    if (busy || stopping) return;
    if (cloud) {
      const count = await cloud.flush();
      if (count) console.log('Shared service saved ' + count + ' event(s); Discord delivery is tracked centrally.');
      return;
    }
    const batch = history.next();
    if (!batch) return;
    busy = true;
    try {
      history.begin(batch);
      if (sending) await deliver(webhook, batch.payload);
      else console.log(JSON.stringify(batch.payload, null, 2));
      history.finish(batch, true);
      console.log((sending ? 'Posted' : 'Previewed') + (batch.digest ? ' catch-up summary (' + batch.keys.length + ' events).' : ' announcement.'));
    } catch (error) {
      try { history.finish(batch, false); } catch (_) {}
      console.error(error.message + '. Delivery marked uncertain; it will not be retried automatically.');
    } finally { busy = false; }
  }
  timer = setInterval(() => { flush().catch(e => console.error(e.message)); }, 500);
  const lines = readline.createInterface({ input: child.stdout });
  lines.on('line', line => {
    let message;
    try { message = JSON.parse(line); } catch (_) { return; }
    if (message.status) { status(message.status); return; }
    if (typeof message.packet !== 'string') return;
    if (lastFrame !== message.packet) { lastFrame = message.packet; return; }
    const event = decodePacket(Buffer.from(message.packet, 'base64'));
    if (!event || event.kind === 'heartbeat') return;
    status('Relay marker decoded.');
    if (!seen.firstObservation(event) || (!cloud && !qualifies(event, settings))) return;
    try {
      if (cloud) {
        if (cloud.receive(event)) console.log((event.test ? '[TEST] ' : '') + event.player + ': event saved for shared delivery.');
        flush().catch(e=>console.error(e.message));
        return;
      }
      if (!history.receive(event)) return;
      console.log((event.test ? '[TEST] ' : '') + event.player + ': ' + (event.kind === 'level' ? 'level ' + event.level : (event.itemName || event.itemId) + ' ×' + event.quantity));
      if (history.data.entries[event.player + ':' + event.id].backlog) console.log('Older event saved for the next catch-up summary.');
      flush().catch(e => console.error(e.message));
    } catch (error) { console.error(error.message); }
  });
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
