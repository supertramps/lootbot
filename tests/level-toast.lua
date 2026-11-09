local sent,sounds,stopped=0,0,0
C_ChatInfo.SendAddonMessage=function(prefix,text,channel)
    assert(prefix=='LootBotDing1' and channel=='GUILD'); sent=sent+1
end
PlaySoundFile=function(path,channel) assert(channel=='SFX'); sounds=sounds+1; return true,sounds end
StopSound=function() stopped=stopped+1 end
LootBotDingDriver.scripts.OnEvent(nil,'PLAYER_LOGIN')
local T=LootBotLevelToast
local config=LootBotDB.characters[UnitGUID('player')].popups
assert(config.enabled and config.animation and not config.sound)
T.LevelUp(11); T.LevelUp(70); assert(sent==0)
T.LevelUp(20); T.LevelUp(20); assert(sent==1)
assert(LootBotLevelToastFrame:IsShown() and LootBotLevelToastFrame.name.text=='Alex')
assert(sounds==0)
MockTime=6; LootBotLevelToastFrame.scripts.OnUpdate(); assert(not LootBotLevelToastFrame:IsShown())
-- Member checks, freshness and duplicates apply to broadcasts, never saved history.
T.Receive('D1:30:1780000000','WHISPER','Friend-TestRealm')
T.Receive('D1:30:1780000000','GUILD','Stranger-TestRealm')
T.Receive('D1:30:1779999979','GUILD','Friend-TestRealm')
T.Receive('D1:30:1780000006','GUILD','Friend-TestRealm')
T.Receive('D1:70:1780000000','GUILD','Friend-TestRealm')
assert(not LootBotLevelToastFrame:IsShown())
T.Receive('D1:30:1780000000','GUILD','Friend-TestRealm')
assert(LootBotLevelToastFrame.name.text=='Friend')
T.Receive('D1:30:1780000000','GUILD','Friend-TestRealm')
MockTime=11; LootBotLevelToastFrame.scripts.OnUpdate(); assert(not LootBotLevelToastFrame:IsShown())
-- Existing saved own events and a reload must not create a toast.
LootBotDingDriver.scripts.OnEvent(nil,'PLAYER_LOGIN')
T.Receive('D1:30:1780000000','GUILD','Friend-TestRealm')
assert(not LootBotLevelToastFrame:IsShown())
-- Hidden options, mute and complete local disable, with explicit local-only previews.
assert(T.Command('options')); assert(LootBotPopupOptions:IsShown())
local boxes=LootBotPopupOptions.checks
boxes.sound:SetChecked(true); boxes.sound.scripts.OnClick(boxes.sound)
assert(config.sound)
T.Command('popup test 60'); assert(sent==1 and sounds==1)
assert(LootBotLevelToastFrame.extra.text=="Maybe it's time to touch some grass?")
MockTime=16; LootBotLevelToastFrame.scripts.OnUpdate(); assert(LootBotLevelToastFrame:IsShown())
boxes.sound:SetChecked(false); boxes.sound.scripts.OnClick(boxes.sound); assert(stopped>0)
boxes.enabled:SetChecked(false); boxes.enabled.scripts.OnClick(boxes.enabled)
assert(not LootBotLevelToastFrame:IsShown() and not config.enabled)
T.Receive('D1:40:1780000000','GUILD','Friend-TestRealm'); assert(not LootBotLevelToastFrame:IsShown())
T.Command('popup test 40'); assert(LootBotLevelToastFrame:IsShown() and sent==1 and sounds==1)
boxes.animation:SetChecked(false); boxes.animation.scripts.OnClick(boxes.animation)
MockTime=17; LootBotLevelToastFrame.scripts.OnUpdate()
T.Command('popup off'); assert(not LootBotLevelToastFrame:IsShown())
-- Turning popups off doesn't stop the player's legitimate Discord recording/broadcast path.
T.LevelUp(40); assert(sent==2 and not LootBotLevelToastFrame:IsShown())
LootBotDB.characters[UnitGUID('player')].enabled=false
T.LevelUp(50); assert(sent==2)
assert(not T.Command('newspaper'))
-- Epic loot only, icons replace the portrait, remote repeats are suppressed.
LootBotDB.characters[UnitGUID('player')].enabled=true
T.Command('popup on')
T.Loot({itemId=755,quality=3}); T.Loot({itemId=19364,quality=4,test=true}); assert(sent==2)
T.Loot({itemId=19364,quality=4}); assert(sent==3)
assert(LootBotLevelToastFrame.message.text=='looted an epic!')
T.Command('popup off'); T.Command('popup on')
T.Receive('I1:19364:4:1780000000:1','GUILD','Friend-TestRealm')
assert(LootBotLevelToastFrame:IsShown())
T.Command('popup off'); T.Command('popup on')
T.Receive('I1:19364:4:1780000000:1','GUILD','Friend-TestRealm')
assert(not LootBotLevelToastFrame:IsShown())
T.Receive('I1:755:3:1780000000:2','GUILD','Friend-TestRealm')
assert(not LootBotLevelToastFrame:IsShown())
config.item=false
T.Receive('I1:19364:4:1780000000:3','GUILD','Friend-TestRealm')
assert(not LootBotLevelToastFrame:IsShown())
-- First learned mount only: initial ownership is a silent baseline.
local owned=0
C_MountJournal={GetMountIDs=function() return {1,2} end,
    GetMountInfoByID=function(id) return 'Wolf '..id,123,456,false,true,1,false,false,nil,false,id<=owned end}
T.MountBaseline(); owned=1; T.NewMount(1)
assert(sent==4 and LootBotLevelToastFrame.message.text=='got their first mount!')
T.Command('popup off'); T.Command('popup on')
owned=2; T.NewMount(2); assert(sent==4 and not LootBotLevelToastFrame:IsShown())
config.mountEverOwned=nil; T.MountBaseline(); T.NewMount(2); assert(sent==4)
config.mount=false
T.Receive('M1:1:1780000000','GUILD','Friend-TestRealm'); assert(not LootBotLevelToastFrame:IsShown())
-- Preview buttons ignore category switches but never send data.
T.PreviewMount(); assert(LootBotLevelToastFrame:IsShown() and sent==4)
T.Command('popup off'); T.PreviewItem(); assert(LootBotLevelToastFrame:IsShown() and sent==4)
-- Volume is local to the sound file, saved, quantized and silent at zero.
local lastPath,played= nil,0
PlaySoundFile=function(path,channel) assert(channel=='SFX'); lastPath=path;played=played+1;return true,123 end
SetCVar=function() error('Must not change game sound volume') end
T.Command('options'); assert(config.volume==50)
LootBotPingVolumeSlider:SetValue(30); assert(config.volume==30)
T.PlayPingSound(true); assert(lastPath:find('Victory-30.ogg',1,true) and played==1)
LootBotPingVolumeSlider:SetValue(0);T.PlayPingSound(true);assert(played==1)
LootBotPingVolumeSlider:SetValue(200);assert(config.volume==100)
T.PlayPingSound(true);assert(lastPath:find('Victory-100.ogg',1,true) and played==2)
LootBotPingVolumeSlider:SetValue(40)
LootBotDingDriver.scripts.OnEvent(nil,'PLAYER_LOGIN'); assert(config.volume==40)
config.sound=false; T.PlayPingSound(false); assert(played==2)
T.PlayPingSound(true);assert(played==3) -- explicit audition still works while muted

-- Drag position survives subsequent pings and settings initialization.
T.MovePings(); assert(LootBotPingMover:IsShown())
LootBotPingMover.x=600; LootBotPingMover.y=450
LootBotPingMover.scripts.OnDragStop(LootBotPingMover)
assert(config.position.x==600/UIParent:GetWidth())
assert(config.position.y==450/UIParent:GetHeight())
T.Command('popup test 60')
assert(math.abs(LootBotLevelToastFrame.x-600)<.01 and math.abs(LootBotLevelToastFrame.y-450)<.01)
assert(#LootBotLevelToastFrame.embers==28)
LootBotDingDriver.scripts.OnEvent(nil,'PLAYER_LOGIN')
T.Command('popup off'); T.PreviewMount()
assert(math.abs(LootBotLevelToastFrame.x-600)<.01)
assert(LootBotLevelToastFrame.iconBorder.path:find('PingPortraitRing.tga',1,true))
assert(LootBotLevelToastFrame.iconMask.path=='Interface\\CharacterFrame\\TempPortraitAlphaMask')

-- The stamp scales around a fixed anchor and settles without anchor drift.
config.animation=true
T.Command('popup test 60')
local stampStart=MockTime
MockTime=stampStart+.40; LootBotLevelToastFrame.scripts.OnUpdate()
assert(LootBotLevelToastFrame.stamp.scale>1)
assert(LootBotLevelToastFrame.seal.x==354 and LootBotLevelToastFrame.seal.y==-61)
MockTime=stampStart+.49; LootBotLevelToastFrame.scripts.OnUpdate()
assert(LootBotLevelToastFrame.stamp.scale<1)
MockTime=stampStart+.7; LootBotLevelToastFrame.scripts.OnUpdate()
assert(LootBotLevelToastFrame.stamp.scale==1 and LootBotLevelToastFrame.stamp.y==0)
assert(LootBotLevelToastFrame.seal.x==354 and LootBotLevelToastFrame.seal.y==-61)
