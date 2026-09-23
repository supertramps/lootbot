// Update the Worker's Discord secret after deploying code. Never log it.
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const here=path.dirname(fileURLToPath(import.meta.url));
const project=process.argv[2]||'F:\\LootBot';
const env={...process.env};for(const key of Object.keys(env))if(key.toLowerCase()==='psmodulepath')delete env[key];
const read=spawnSync('powershell.exe',['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join(project,'Start-LootBot.ps1'),'-Mode','ReadWebhook'],{env,encoding:'utf8',windowsHide:true});
if(read.status!==0)throw new Error('Could not decrypt the existing Discord webhook');
const secret=read.stdout.trim();
if(!/^https:\/\/discord\.com\/api(?:\/v\d+)?\/webhooks\/\d+\/[A-Za-z0-9_-]+$/.test(secret))throw new Error('Stored Discord webhook is invalid');
const cli=path.join(here,'node_modules','wrangler','bin','wrangler.js');
const save=spawnSync(process.execPath,[cli,'secret','put','DISCORD_WEBHOOK'],{cwd:here,input:secret+'\n',encoding:'utf8',windowsHide:true});
if(save.status!==0)throw new Error('Could not store the Discord webhook in the Worker');
console.log('Discord webhook restored as a Cloudflare secret.');
