'use strict';
const fs = require('fs');
const { discordPayload, escapeMarkdown } = require('./protocol');
const keyFor = e => `${e.player}:${e.id}`;

function digestPayload(events) {
  const players = new Map();
  for (const e of events) {
    if (!players.has(e.player)) players.set(e.player, []);
    players.get(e.player).push(e);
  }
  const loot = events.filter(e => e.kind !== 'level').length;
  const levels = events.length - loot;
  const testCount = events.filter(e => e.test).length;
  let description = `**${loot} loot events · ${levels} level milestones · ${players.size} players**\n`;
  if (testCount) description += `Includes ${testCount} labeled synthetic test event(s).\n`;
  let shown = 0;
  for (const [player, list] of [...players].sort((a, b) => a[0].localeCompare(b[0]))) {
    const milestones = list.filter(e => e.kind === 'level').map(e => `${e.test ? 'TEST ' : ''}${e.level}`);
    const items = list.filter(e => e.kind !== 'level');
    const parts = [];
    if (milestones.length) parts.push(`level ${milestones.slice(0, 10).join(', ')}${milestones.length > 10 ? '…' : ''}`);
    if (items.length) {
      parts.push(items.slice(0, 2).map(e => `[${e.test ? 'TEST: ' : ''}${escapeMarkdown((e.itemName || `Item #${e.itemId}`).slice(0, 55))}](https://www.wowhead.com/classic/item=${e.itemId})${e.quantity > 1 ? ` ×${e.quantity}` : ''}`).join(', '));
      if (items.length > 2) parts.push(`+${items.length - 2} other loot events`);
    }
    const line = `\n**${escapeMarkdown(player)}** — ${parts.join('; ')}\n`;
    if (description.length + line.length > 3700) break;
    description += line; shown++;
  }
  if (shown < players.size) description += `\n…and ${players.size - shown} other players. Full records remain in the relay's local history.`;
  const times = events.map(e => e.timestamp).sort((a, b) => a - b);
  return { username: 'LootBot', allowed_mentions: { parse: [] }, embeds: [{
    title: `${testCount === events.length ? 'TEST — ' : ''}Guild catch-up`, description, color: 0x79d9a6,
    footer: { text: `Newly synced records · ${new Date(times[0] * 1000).toISOString().slice(0, 10)} to ${new Date(times[times.length - 1] * 1000).toISOString().slice(0, 10)} UTC · Coverage depends on addon sync` }
  }] };
}

class History {
  constructor(file, settings, now = Date.now() / 1000, legacy = {}) {
    this.file = file; this.settings = settings; this.started = now;
    this.data = file && fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : { version: 1, entries: {}, lastDigest: 0 };
    if (this.data.version !== 1 || !this.data.entries || typeof this.data.entries !== 'object') throw new Error('Invalid LootBot history file. Preserve it before troubleshooting.');
    this.legacy = legacy;
    for (const [key, entry] of Object.entries(this.data.entries)) {
      if (!entry.event || !['pending', 'sending', 'sent', 'uncertain'].includes(entry.state)) throw new Error('Invalid event in LootBot history.');
      if (entry.event.timestamp < now - 31 * 86400 && entry.state === 'sent') delete this.data.entries[key];
      else if (entry.state === 'sending') entry.state = 'uncertain';
      else if (entry.state === 'pending') entry.backlog = true;
    }
    this.save();
  }
  save() {
    if (!this.file) return;
    const tmp = this.file + '.tmp'; fs.writeFileSync(tmp, JSON.stringify(this.data)); fs.renameSync(tmp, this.file);
  }
  receive(event, now = Date.now() / 1000) {
    const key = keyFor(event);
    if (this.data.entries[key] || this.legacy[key]) return false;
    if (Object.keys(this.data.entries).length >= 100000) throw new Error('History capacity reached; no new events can be stored.');
    this.data.entries[key] = { event, received: now, state: 'pending',
      backlog: event.timestamp < this.started - 5 || now - event.timestamp > this.settings.liveAgeSeconds };
    this.save(); return true;
  }
  next(now = Date.now() / 1000) {
    const pending = Object.values(this.data.entries).filter(e => e.state === 'pending');
    const live = pending.find(e => !e.backlog);
    if (live) return { keys: [keyFor(live.event)], payload: discordPayload(live.event), digest: false };
    const old = pending.filter(e => e.backlog);
    if (!old.length) return null;
    const ready = Math.max(old.reduce((earliest,e) => Math.min(earliest,e.received), Infinity) + this.settings.digestDelaySeconds,
      this.data.lastDigest + this.settings.digestCooldownSeconds);
    if (now < ready) return null;
    return { keys: old.map(e => keyFor(e.event)), payload: digestPayload(old.map(e => e.event)), digest: true };
  }
  begin(batch) { for (const key of batch.keys) this.data.entries[key].state = 'sending'; this.save(); }
  finish(batch, success, now = Date.now() / 1000) {
    for (const key of batch.keys) this.data.entries[key].state = success ? 'sent' : 'uncertain';
    if (batch.digest && success) this.data.lastDigest = now;
    this.save();
  }
  uncertainCount() { return Object.values(this.data.entries).filter(e => e.state === 'uncertain').length; }
}
module.exports = { History, digestPayload, keyFor };
