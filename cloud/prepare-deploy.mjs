import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.dirname(here);
const project=process.argv[2]||'F:\\LootBot';
const registration=JSON.parse(fs.readFileSync(path.join(root,'relay-registration.json'),'utf8'));
const quote=s=>"'"+String(s).replaceAll("'","''")+"'";
const sql=[`INSERT INTO relays(id,jwk,admin) VALUES(${quote(registration.id)},${quote(JSON.stringify(registration.publicKey))},1) ON CONFLICT(id) DO UPDATE SET admin=1;`];
const entries=new Map();
const old=path.join(project,'state','delivered.json');
if(fs.existsSync(old))for(const key of Object.keys(JSON.parse(fs.readFileSync(old,'utf8'))))entries.set(key,{body:'{}',state:'sent'});
const file=path.join(project,'state','history.json');
if(fs.existsSync(file))for(const [key,entry] of Object.entries(JSON.parse(fs.readFileSync(file,'utf8')).entries)){
  if(['sent','sending','uncertain','pending'].includes(entry.state))entries.set(key,{body:JSON.stringify(entry.event),state:entry.state==='sending'?'uncertain':entry.state});
}
const t=Math.floor(Date.now()/1000);
for(const [id,e] of entries)sql.push(`INSERT OR IGNORE INTO events(id,body,received,backlog,state) VALUES(${quote(id)},${quote(e.body)},${t},1,${quote(e.state)});`);
fs.writeFileSync(path.join(here,'bootstrap.sql'),sql.join('\n')+'\n');
console.log('Prepared administrator registration and '+entries.size+' previous delivery records. No webhook credentials included.');
