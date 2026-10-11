'use strict';
// Export actual Lua issue text for a local typography proof (not a game capture).
const fs=require('fs'),path=require('path');
const {lua,lauxlib,lualib,to_luastring}=require('fengari');
const L=lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
function run(source){lua.lua_settop(L,0); if(lauxlib.luaL_dostring(L,to_luastring(source))!==lua.LUA_OK)throw Error(lua.lua_tojsstring(L,-1));}
run(fs.readFileSync(path.join(__dirname,'../addon/LootBot/GuildStatistics.lua'),'utf8'));
const out=process.argv[2]; fs.mkdirSync(out,{recursive:true});
for(const mode of ['welcome','weekly']){
  run(mode==='welcome'?'return LootBotGuildStatistics.Launch(1780000000)':`
    local w=LootBotGuildStatistics.Week(1780000000)-1
    return LootBotGuildStatistics.Edition({weeks={[w]={
      ['Gruk-Realm']={first=1,last=2,start={[60]=100,[98]=400,[1518]=100,[193]=500},finish={[60]=118,[98]=426,[1518]=110,[193]=500}},
      ['Mara-Realm']={first=1,last=2,start={[60]=10,[98]=20,[1518]=90,[193]=100},finish={[60]=12,[98]=75,[1518]=185,[193]=100}}
    }}},1780000000)`);
  lua.lua_getfield(L,-1,to_luastring('fields'));
  const fields={}; lua.lua_pushnil(L);
  while(lua.lua_next(L,-2)){fields[lua.lua_tojsstring(L,-2)]=lua.lua_tojsstring(L,-1); lua.lua_pop(L,1);}
  fs.writeFileSync(path.join(out,mode+'.json'),JSON.stringify(fields,null,2));
}
lua.lua_close(L);
