'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {identity,signed}=require('./cloud');
const ROOT=path.resolve(__dirname,'..');
async function run(){
 const config=JSON.parse(fs.readFileSync(path.join(ROOT,'cloud-config.json'),'utf8')),id=identity();
 const input=JSON.parse(fs.readFileSync(0,'utf8'));
 let route,data={};
 if(['preview-item','test-item','preview-level','test-level','preview-digest','test-digest'].includes(input.action)){
  route=input.action.startsWith('preview')?'/preview':'/test';const loot=input.action.endsWith('item');
  const digest=input.action.endsWith('digest');
  data={kind:digest?'digest':loot?'loot':'level',id:input.id||crypto.randomUUID(),...(digest?{}:loot?{itemId:input.value}:{level:input.value})};
 }else if(input.action==='settings'){route='/settings';if(input.settings)data={settings:input.settings};}
 else if(input.action==='status')route='/status';
 else if(input.action==='relays'){route='/relays';data={registration:input.registration};}
 else throw new Error('Unknown action');
 console.log(JSON.stringify(await signed(config.url,id,route,data)));
}
run().catch(e=>{console.log(JSON.stringify({error:e.message}));process.exitCode=1;});
