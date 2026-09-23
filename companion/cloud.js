'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {spawnSync}=require('child_process');
const ROOT=path.resolve(__dirname,'..');
function protect(input,decrypt=false) {
  const env={...process.env}; for(const k of Object.keys(env))if(k.toLowerCase()==='psmodulepath')delete env[k];
  const script="Add-Type -AssemblyName System.Security; $b=[Convert]::FromBase64String([Console]::In.ReadToEnd()); $r=[Security.Cryptography.ProtectedData]::"+(decrypt?'Unprotect':'Protect')+"($b,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser); [Console]::Write([Convert]::ToBase64String($r))";
  const r=spawnSync('powershell.exe',['-NoProfile','-Command',script],{input:Buffer.from(input).toString('base64'),encoding:'utf8',windowsHide:true,env});
  if(r.status!==0)throw new Error('Could not read or save the encrypted relay identity for this Windows user.');
  return Buffer.from(r.stdout.trim(),'base64');
}
function identity(root=ROOT) {
  const file=path.join(root,'relay-identity.json');
  if(!fs.existsSync(file)) {
    const pair=crypto.generateKeyPairSync('ec',{namedCurve:'prime256v1'});
    const publicKey=pair.publicKey.export({format:'jwk'}),id=crypto.randomBytes(16).toString('hex');
    const secret=pair.privateKey.export({format:'pem',type:'pkcs8'});
    const data={id,publicKey,encrypted:protect(Buffer.from(secret)).toString('base64')};
    fs.writeFileSync(file,JSON.stringify(data),{flag:'wx'});
  }
  const data=JSON.parse(fs.readFileSync(file,'utf8'));
  return {...data,privateKey:protect(Buffer.from(data.encrypted,'base64'),true).toString('utf8')};
}
function endpoint(raw) {
  const u=new URL(raw);
  if(u.protocol!=='https:'||u.username||u.password||u.port||u.pathname!=='/'||u.search||u.hash||!u.hostname.endsWith('.workers.dev'))throw new Error('Expected a Cloudflare workers.dev HTTPS service address.');
  return u.origin;
}
async function signed(url,id,route,data,send=fetch) {
  const body=JSON.stringify(data),stamp=String(Math.floor(Date.now()/1000));
  const sig=crypto.sign('sha256',Buffer.from(stamp+'\n'+route+'\n'+body),{key:id.privateKey,dsaEncoding:'ieee-p1363'}).toString('base64');
  let res;
  try {res=await send(endpoint(url)+route,{method:'POST',headers:{'Content-Type':'application/json','X-LootBot-Relay':id.id,'X-LootBot-Time':stamp,'X-LootBot-Signature':sig},body,signal:AbortSignal.timeout(15000)});}catch{throw new Error('Shared service unreachable; events remain queued.');}
  if(!res.ok){const error=await res.json().catch(()=>({}));throw new Error(res.status===401?'Relay is not registered with the shared service.':typeof error.error==='string'?error.error.slice(0,200):'Shared service returned HTTP '+res.status+'; events remain queued.');}
  return res.json();
}
class CloudQueue {
  constructor(file,config,id) {
    this.file=file;this.config=config;this.id=id;this.data=fs.existsSync(file)?JSON.parse(fs.readFileSync(file,'utf8')):{entries:{}};
    this.busy=false;this.nextTry=0;this.nextPulse=0;this.delay=2000;
    for(const [key,v] of Object.entries(this.data.entries))if(v.state==='accepted'&&v.event.timestamp<Date.now()/1000-31*86400)delete this.data.entries[key];
    this.save();
  }
  save(){const tmp=this.file+'.tmp';fs.writeFileSync(tmp,JSON.stringify(this.data));fs.renameSync(tmp,this.file);}
  receive(event){const key=event.player+':'+event.id;if(this.data.entries[key])return false;if(Object.keys(this.data.entries).length>=100000)throw new Error('Relay queue is full.');this.data.entries[key]={event,state:'pending'};this.save();return true;}
  async flush(send=fetch){
    if(this.busy||Date.now()<this.nextTry)return;
    let expired=false;
    for(const v of Object.values(this.data.entries))if(v.state==='pending'&&v.event.timestamp<Date.now()/1000-30*86400+60){v.state='expired';expired=true;}
    if(expired)this.save();
    const entries=Object.values(this.data.entries).filter(v=>v.state==='pending').slice(0,20);
    if(!entries.length&&Date.now()<this.nextPulse)return;
    this.busy=true;
    try {
      if(!entries.length){await signed(this.config.url,this.id,'/pulse',{},send);this.nextPulse=Date.now()+10000;this.delay=2000;return;}
      const r=await signed(this.config.url,this.id,'/events',{events:entries.map(v=>v.event)},send);if(r.accepted!==true)throw new Error('Service did not acknowledge the events.');for(const v of entries)v.state='accepted';this.save();this.delay=2000;return entries.length;
    }
    catch(e){this.nextTry=Date.now()+this.delay;this.delay=Math.min(60000,this.delay*2);throw e;}
    finally{this.busy=false;}
  }
}
if(require.main===module) {
  try {
    const id=identity();
    if(process.argv.includes('--status')) {
      const config=JSON.parse(fs.readFileSync(path.join(ROOT,'cloud-config.json'),'utf8'));
      signed(config.url,id,'/status',{}).then(r=>console.log(JSON.stringify(r))).catch(e=>{console.error(e.message);process.exitCode=1;});
    } else {
      const publicData={id:id.id,publicKey:id.publicKey};
      fs.writeFileSync(path.join(ROOT,'relay-registration.json'),JSON.stringify(publicData,null,2));
      console.log(JSON.stringify(publicData));
    }
  }catch(e){console.error(e.message);process.exitCode=1;}
}
module.exports={identity,endpoint,signed,CloudQueue};
