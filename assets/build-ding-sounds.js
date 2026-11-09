'use strict';
// Original quiet synthesized chimes. No third-party audio or system volume changes.
const fs=require('fs'), path=require('path');
function make(name,max,style='warm') {
  const rate=22050, length=max?1.45:1.05, count=Math.floor(rate*length);
  const pcm=Buffer.alloc(count*2); let seed=771;
  const notes=max?[[.08,523.25],[.22,659.25],[.37,783.99]]:[[.08,659.25],[.22,783.99]];
  for(let i=0;i<count;i++) {
    const t=i/rate; seed=(Math.imul(seed,1664525)+1013904223)>>>0;
    let v=(seed/4294967296*2-1)*.018*Math.sin(Math.PI*Math.min(1,t/.16))**2*(t<.16?1:0);
    for(const [start,base] of notes) {
      const f=base*(style==='bell'?1.5:style==='wood'?.75:1);
      const s=t-start;
      if(s>=0) v+=.095*(1-Math.exp(-s*70))*Math.exp(-s*(style==='wood'?14:style==='bell'?7:5))*(Math.sin(2*Math.PI*f*s)+.18*Math.sin(2*Math.PI*f*(style==='bell'?2.76:2)*s));
    }
    v*=Math.min(1,(length-t)/.1);
    pcm.writeInt16LE(Math.round(Math.max(-1,Math.min(1,v))*32767),i*2);
  }
  const h=Buffer.alloc(44); h.write('RIFF');h.writeUInt32LE(36+pcm.length,4);h.write('WAVEfmt ',8);
  h.writeUInt32LE(16,16);h.writeUInt16LE(1,20);h.writeUInt16LE(1,22);h.writeUInt32LE(rate,24);
  h.writeUInt32LE(rate*2,28);h.writeUInt16LE(2,32);h.writeUInt16LE(16,34);h.write('data',36);h.writeUInt32LE(pcm.length,40);
  fs.writeFileSync(path.join(__dirname,'../addon/LootBot',name),Buffer.concat([h,pcm]));
}
make('Ding.wav',false);make('Ding60.wav',true);
make('DingBell.wav',false,'bell');make('DingWood.wav',false,'wood');
