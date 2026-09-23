// Run after authorizing Wrangler. Only the named LootBot Worker and database are changed.
import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';import {spawnSync} from 'node:child_process';
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.dirname(here),cli=path.join(here,'node_modules','wrangler','bin','wrangler.js');
const project=process.argv[2]||'F:\\LootBot';
function command(args,input){const p=spawnSync(process.execPath,[cli,...args],{cwd:here,encoding:'utf8',input,windowsHide:true});if(p.stdout)process.stdout.write(p.stdout);if(p.status!==0){throw new Error('Cloudflare command failed: '+args.slice(0,3).join(' '));}}
const prep=spawnSync(process.execPath,[path.join(here,'prepare-deploy.mjs'),project],{cwd:here,encoding:'utf8',windowsHide:true});if(prep.status!==0)throw new Error('Could not prepare existing delivery history');process.stdout.write(prep.stdout);
command(['d1','migrations','apply','lootbot','--remote']);
command(['d1','execute','lootbot','--remote','--file','bootstrap.sql','--yes']);
command(['deploy','--keep-vars']);
console.log('LootBot service deployed. Existing Cloudflare settings and secrets were preserved.');
