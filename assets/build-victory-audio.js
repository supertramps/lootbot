'use strict';
// node assets/build-victory-audio.js <ffmpeg-executable> <source-mp3>
const fs=require('fs'),path=require('path'),{spawnSync}=require('child_process');
const [ffmpeg,source]=process.argv.slice(2);
if(!ffmpeg||!source)throw Error('Provide FFmpeg and the source MP3.');
const out=path.join(__dirname,'../addon/LootBot/Sounds');fs.mkdirSync(out,{recursive:true});
for(let volume=10;volume<=100;volume+=10){
 const target=path.join(out,`Victory-${volume}.ogg`);
 const result=spawnSync(ffmpeg,['-hide_banner','-loglevel','error','-y','-i',source,'-map_metadata','-1','-vn','-af',`volume=${volume/100}`,'-ar','44100','-c:a','libvorbis','-q:a','3',target],{encoding:'utf8'});
 if(result.status!==0)throw Error(result.stderr||'Audio encoding failed');
}
console.log('Encoded ten ping-only volume levels. Total bytes: '+fs.readdirSync(out).filter(n=>n.startsWith('Victory-')).reduce((n,f)=>n+fs.statSync(path.join(out,f)).size,0));
