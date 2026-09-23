'use strict';
const https = require('https');

function post(url, payload, request = https.request) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify(payload);
    const req = request(url, { method: 'POST', headers: {
      'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body),
      'User-Agent': 'LootBot/0.1'
    } }, res => {
      let response = '';
      res.setEncoding('utf8');
      res.on('data', chunk => { if (response.length < 65536) response += chunk; });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) return resolve();
        const error = new Error(`Discord returned HTTP ${res.statusCode}`);
        error.status = res.statusCode;
        if (res.statusCode === 429) {
          try { error.retryAfter = Math.max(1, Math.min(120, Number(JSON.parse(response).retry_after) || 1)); }
          catch (_) { error.retryAfter = 5; }
        }
        reject(error);
      });
      res.on('error', () => reject(new Error('Discord response interrupted')));
    });
    req.setTimeout(10000, () => req.destroy(new Error('Request timed out')));
    // Never propagate an error containing a credential-bearing request URL.
    req.on('error', () => reject(new Error('Discord connection failed or timed out')));
    req.end(body);
  });
}

async function deliver(url, payload, send = post, sleep = ms => new Promise(r => setTimeout(r, ms))) {
  for (let attempt = 0; attempt < 4; attempt++) {
    try { await send(url, payload); return; }
    catch (error) {
      // Only retry explicit rejections. A network timeout may have occurred AFTER posting.
      if (error.status !== 429 || attempt === 3) throw error;
      await sleep(error.retryAfter * 1000);
    }
  }
}
module.exports = { post, deliver };
