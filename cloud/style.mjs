export const titles = [
 ['Vendor treasure!','Every copper counts!','The backpack grows heavier!','One goblin’s treasure!','A humble discovery!','Loot is loot!','The vendor will love this!','Pocket change acquired!','A very grey day!','Inventory space: reduced!','A small fortune awaits!','The junk collection grows!'],
 ['A little something!','Fresh loot!','Another find for the bags!','The adventure pays off!','A useful discovery!','Something for the collection!','Bag it and carry on!','The loot keeps coming!','A find along the way!','Another treasure claimed!','A small victory!','Spoils of adventure!'],
 ['A flash of green!','An uncommon find!','Green looks good on you!','A lucky little drop!','Something worth a closer look!','The loot luck is warming up!','An unexpected upgrade?','A green gem for the bags!','A promising discovery!','Uncommon luck strikes!','A little green magic!','That’s a keeper!'],
 ['A bolt from the blue!','Rare luck strikes!','Blue loot, big smiles!','Now that’s a nice drop!','A rare find for the guild!','The loot gods noticed!','A splash of blue!','A treasure worth sharing!','A rare moment of luck!','That deserves a cheer!','Blue skies and better loot!','The adventure just paid off!'],
 ['Epic luck strikes!','Purple reign!','An epic moment!','The loot gods have spoken!','A purple prize appears!','Now that’s worth celebrating!','Epic treasure claimed!','The guild has something to cheer!','A very purple day!','Dream loot, real drop!','The epic collection grows!','That drop deserves applause!'],
 ['A legendary moment!','Orange you glad you came?','History in the making!','The stuff of legends!','A legend joins the bags!','Stop everything—legendary loot!','The guild will remember this!','Fortune favors the legendary!','An orange glow on the horizon!','A drop for the history books!','Legends are made of this!','The ultimate loot celebration!'],
 ['An artifact appears!','A relic of greatness!','A storied treasure!','Something extraordinary!','A piece of history!','An ancient prize!','Power from another age!','A remarkable discovery!','A treasure with a story!','Beyond ordinary loot!','A relic worth remembering!','An extraordinary moment!'],
 ['An heirloom for the ages!','A lasting treasure!','A gift for the next adventure!','A collection worth keeping!','A familiar golden glow!','Treasure for tomorrow!','An heirloom joins the family!','Something to pass along!','A timeless find!','The legacy grows!','A future adventurer’s prize!','Loot with a long story!'],
 ['A special reward!','Another prize claimed!','A token of success!','A reward well earned!','Something special in the bags!','The collection grows!','A little progress!','A prize for the journey!','Another step forward!','A welcome reward!','Treasure takes many forms!','A special find!']
];
export function titleFor(e) { const list=titles[e.quality]||titles[1];let n=0;for(const c of e.id)n=(n*31+c.charCodeAt(0))>>>0;return list[n%list.length]; }
export async function itemInfo(id,db,fetcher=fetch) {
 if(!Number.isInteger(id)||id<1||id>10000000)throw new Error('Invalid item ID');
 const cached=await db.prepare('SELECT body,updated FROM items WHERE id=?').bind(id).first();
 if(cached&&cached.updated>Math.floor(Date.now()/1000)-604800)return JSON.parse(cached.body);
 try {
  const res=await fetcher('https://nether.wowhead.com/classic/tooltip/item/'+id,{signal:AbortSignal.timeout(5000)});
  if(!res.ok)throw new Error('Item lookup unavailable');const data=await res.json();
  if(typeof data.name!=='string'||!data.name||!Number.isInteger(data.quality)||data.quality<0||data.quality>8||typeof data.icon!=='string'||!/^[-a-z0-9_]+$/i.test(data.icon))throw new Error('Item not found');
  const result={name:data.name.slice(0,160),quality:data.quality,icon:'https://wow.zamimg.com/images/wow/icons/large/'+data.icon.toLowerCase()+'.jpg'};
  await db.prepare('INSERT INTO items(id,body,updated) VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET body=excluded.body,updated=excluded.updated').bind(id,JSON.stringify(result),Math.floor(Date.now()/1000)).run();return result;
 }catch(e){if(cached)return JSON.parse(cached.body);throw e;}
}
