'use strict';
const { TextDecoder } = require('util');

function adler32(bytes) {
  let a = 1, b = 0;
  for (const value of bytes) { a = (a + value) % 65521; b = (b + a) % 65521; }
  return (b * 65536 + a) >>> 0;
}

function decodePacket(packet, now = Date.now() / 1000) {
  if (packet.length !== 256 || !['LB01', 'LB02'].includes(packet.toString('ascii', 0, 4))) return null;
  const length = packet.readUInt16BE(4);
  if (length < 2 || length > 246) return null;
  if (adler32(packet.subarray(0, 6 + length)) !== packet.readUInt32BE(6 + length)) return null;
  let values;
  try { values = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(packet.subarray(6, 6 + length))); }
  catch (_) { return null; }
  if (!Array.isArray(values) || ![8, 10].includes(values.length)) return null;
  const [id, player, itemId, quality, quantity, itemName, timestamp, test] = values;
  const kind = values[8] || (itemId === 0 ? 'heartbeat' : 'loot');
  const level = values[9] || 0;
  if (typeof id !== 'string' || !/^[A-Za-z0-9-]{1,100}$/.test(id) ||
      typeof player !== 'string' || player.length > 120 ||
      typeof itemName !== 'string' || itemName.length > 160 ||
      !Number.isInteger(itemId) || itemId < 0 || itemId > 10000000 ||
      !Number.isInteger(quality) || quality < -1 || quality > 8 ||
      !Number.isInteger(quantity) || quantity < 0 || quantity > 1000000 ||
      !Number.isInteger(timestamp) || now - timestamp > 30 * 86400 || timestamp - now > 120 ||
      typeof test !== 'boolean') return null;
  if (!['loot', 'level', 'heartbeat'].includes(kind) || !Number.isInteger(level)) return null;
  if (kind === 'loot' && (!player || itemId < 1 || quantity < 1 || level !== 0)) return null;
  if (kind === 'level' && (!player || itemId !== 0 || level < 10 || level > 200 || level % 10)) return null;
  if (kind === 'heartbeat' && itemId !== 0) return null;
  return { id, player, itemId, quality, quantity, itemName, timestamp, test, kind, level };
}

function encodePacket(values) {
  const body = Buffer.from(JSON.stringify(values));
  if (body.length > 246) throw new Error('Packet exceeds optical frame capacity');
  const packet = Buffer.alloc(256);
  packet.write(values.length === 10 ? 'LB02' : 'LB01'); packet.writeUInt16BE(body.length, 4); body.copy(packet, 6);
  packet.writeUInt32BE(adler32(packet.subarray(0, body.length + 6)), body.length + 6);
  return packet;
}

function qualifies(event, settings) {
  if (event.kind === 'level') return event.test || settings.levelMilestones.includes(event.level);
  return event.itemId > 0 && (event.test || event.quality >= settings.minimumQuality ||
    settings.watchItemIds.includes(event.itemId));
}

function escapeMarkdown(text) { return text.replace(/([\\`*_{}\[\]()<>~|])/g, '\\$1'); }

function discordPayload(event) {
  if (event.kind === 'level') return {
    username: 'LootBot', allowed_mentions: { parse: [] }, embeds: [{
      title: event.test ? 'TEST — Level milestone' : `Level ${event.level}!`,
      description: `**${escapeMarkdown(event.player)}** reached **level ${event.level}**!`,
      color: 0xffd166, timestamp: new Date(event.timestamp * 1000).toISOString(),
      footer: { text: event.test ? 'Synthetic test — no actual level-up' : 'Recorded by the player’s addon at level-up' }
    }]
  };
  const itemUrl = `https://www.wowhead.com/classic/item=${event.itemId}`;
  const names = ['Poor', 'Common', 'Uncommon', 'Rare', 'Epic', 'Legendary', 'Artifact', 'Heirloom', 'Token'];
  const colors = [0x9d9d9d, 0xffffff, 0x1eff00, 0x0070dd, 0xa335ee, 0xff8000, 0xe6cc80, 0x00ccff];
  return {
    username: 'LootBot', allowed_mentions: { parse: [] },
    embeds: [{
      title: event.test ? 'TEST — LootBot connection check' : 'A drop worth celebrating!',
      description: `**${escapeMarkdown(event.player)}** received **[${escapeMarkdown(event.itemName || `Item #${event.itemId}`)}](${itemUrl})**${event.quantity > 1 ? ` ×${event.quantity}` : ''}.`,
      color: colors[event.quality] || 0x79d9a6,
      fields: [{ name: 'Quality', value: names[event.quality] || 'Unknown', inline: true },
        { name: 'Item ID', value: String(event.itemId), inline: true }],
      timestamp: new Date(event.timestamp * 1000).toISOString(),
      footer: { text: event.test ? 'Synthetic test event — no actual loot drop' : 'Detected from the player’s own loot message' }
    }]
  };
}

function validateWebhook(raw) {
  let url;
  try { url = new URL(raw); } catch (_) { throw new Error('Invalid Discord webhook URL. Run Setup.'); }
  if (url.protocol !== 'https:' || url.hostname !== 'discord.com' || url.port ||
      url.username || url.password || !/^\/api(?:\/v\d+)?\/webhooks\/\d+\/[A-Za-z0-9_-]+$/.test(url.pathname) ||
      url.search || url.hash) throw new Error('Expected an https://discord.com/api/webhooks/... URL.');
  url.searchParams.set('wait', 'true');
  return url;
}

function validateSettings(input) {
  const defaults = { minimumQuality: 4, watchItemIds: [], pollMs: 100, markerX: 16, markerY: 16, cellSize: 1, processId: 0,
    levelMilestones: Array.from({ length: 20 }, (_, i) => (i + 1) * 10), digestDelaySeconds: 120,
    digestCooldownSeconds: 900, liveAgeSeconds: 90 };
  const s = { ...defaults, ...input };
  for (const [key, min, max] of [['minimumQuality', 0, 8], ['pollMs', 50, 1000],
    ['markerX', 0, 10000], ['markerY', 0, 10000], ['cellSize', 1, 10], ['processId', 0, 2147483647],
    ['digestDelaySeconds', 10, 3600], ['digestCooldownSeconds', 10, 86400], ['liveAgeSeconds', 5, 300]]) {
    if (!Number.isInteger(s[key]) || s[key] < min || s[key] > max) throw new Error(`Invalid setting: ${key}`);
  }
  if (!Array.isArray(s.watchItemIds) || s.watchItemIds.some(id => !Number.isInteger(id) || id < 1 || id > 10000000))
    throw new Error('watchItemIds must be an array of positive item IDs.');
  if (!Array.isArray(s.levelMilestones) || s.levelMilestones.some(n => !Number.isInteger(n) || n < 10 || n > 200 || n % 10))
    throw new Error('levelMilestones must contain multiples of ten between 10 and 200.');
  return s;
}

class EventTracker {
  constructor() { this.events = new Map(); }
  firstObservation(event, now = Date.now()) {
    const key = `${event.player}:${event.id}`;
    if (this.events.has(key)) return false;
    for (const [oldKey, time] of this.events) if (now - time > 300000) this.events.delete(oldKey);
    this.events.set(key, now);
    return true;
  }
}
module.exports = { adler32, decodePacket, encodePacket, qualifies, discordPayload, validateWebhook, validateSettings, EventTracker, escapeMarkdown };
