'use strict';
// Actual Lua edition/layout export with explicitly made-up proof data.
const fs=require('fs'),path=require('path');
const {lua,lauxlib,lualib,to_luastring}=require('fengari');
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
function run(source){lua.lua_settop(L,0);if(lauxlib.luaL_dostring(L,to_luastring(source))!==lua.LUA_OK)throw Error(lua.lua_tojsstring(L,-1));}
function read(index){
  const type=lua.lua_type(L,index);
  if(type===lua.LUA_TSTRING)return lua.lua_tojsstring(L,index);
  if(type===lua.LUA_TNUMBER)return lua.lua_tonumber(L,index);
  if(type===lua.LUA_TBOOLEAN)return !!lua.lua_toboolean(L,index);
  if(type!==lua.LUA_TTABLE)return null;
  const at=lua.lua_absindex(L,index),obj={};lua.lua_pushnil(L);
  while(lua.lua_next(L,at)){const key=lua.lua_type(L,-2)===lua.LUA_TNUMBER?lua.lua_tonumber(L,-2):lua.lua_tojsstring(L,-2);obj[key]=read(-1);lua.lua_pop(L,1);}
  const keys=Object.keys(obj);return keys.length&&keys.every((_,i)=>String(i+1) in obj)?keys.map((_,i)=>obj[i+1]):obj;
}
for(const name of ['GuildStatistics','NewspaperEdition'])run(fs.readFileSync(path.join(__dirname,'../addon/LootBot/'+name+'.lua'),'utf8'));
run(`
  local now=1793707200
  local result=LootBotNewspaperEdition.Demo(now)
  local alternate=LootBotNewspaperEdition.Demo(now+604800)
  result.pages[#result.pages+1]=alternate.pages[1]
  return {sample=true,pages=result.pages,layouts=LootBotNewspaperEdition.Layouts}
`);
const out=process.argv[2];fs.mkdirSync(out,{recursive:true});
fs.writeFileSync(path.join(out,'pages.json'),JSON.stringify(read(-1),null,2));lua.lua_close(L);
