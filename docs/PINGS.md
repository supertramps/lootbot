# Peon pings — 0.4.3

0.4.5: All ping types now use the owner's chosen victory-trumpet recording. Options include a
saved 0–100% ping-volume slider (10% steps; default 50%) and a local Test sound button. Zero is
silent. The sound checkbox continues to mute automatic notifications; explicit Test sound can
audition the recording while muted. Changing the volume stops the current sound; the next
play uses the new level. The addon never writes game-wide volume CVars. WoW's SFX and master
settings still apply. Ten small Ogg files supply independent gain without undocumented APIs.
Rebuild with `node assets/build-victory-audio.js <ffmpeg> <source.mp3>`; attribution is bundled
in `addon/LootBot/Sounds/CREDITS.txt`. The earlier synthesized WAVs are unused prototypes.

Open the local options window with `/lootbot options` (deliberately omitted from normal chat help).
The minimap icon opens the newspaper on left-click and options on right-click; its tooltip lists both.

Each character saves a master switch, level / epic-loot / first-mount switches, sound and animation.
Sound is off by default. Preview buttons show local dummy events even with pings disabled and never
write relay events or send anything to Discord or other players. Muting stops the current ping sound.

The compact, click-through parchment appears near the top center. Levels use the peon; items and mounts
use game icons. A 0.3-second parchment reveal, a small seal bounce and a fade accompany four seconds
of display. Level 60 lasts six seconds and adds a subtle gold shimmer and the grass joke.
Level flair increases gradually; epic loot uses purple, legendary loot gold, and mounts green.
Level 60 also has eight tiny animated embers using an existing game texture, without sprite sheets.
The animation update callback is detached when the ping ends, so no idle particle processing runs.

Fresh level milestones (10–60), epic-or-higher real loot, and a first learned mount send one short
`LootBotDing1` GUILD addon message. No visible guild chat is sent. The receiving addon validates guild
membership, payload fields, a 20-second freshness limit, and saved duplicate keys. A bounded queue
shows only one ping at a time and discards stale queued messages. This doesn't use the pixel strip,
the desktop relay, Cloudflare or Discord. All participants need 0.4.3 for these guild pings; delivery
still depends on the game's GUILD addon-message transport. No history replay or retries are performed.

Loot reuses the existing own-loot detector and quality policy, never generic chat parsing or test records.
First mount means a newly learned first collected mount reported by `C_MountJournal`, not buying or
looting an unlearned mount item. Ownership is baselined silently at login; uncertain/unavailable journal
data never invents a first acquisition. Clients without a mount journal retain levels and loot. This
path is API/mock tested and still needs a real Forever acquisition check; mount collection semantics
are those exposed by that client (including any account-wide ownership).

Source reference: Blizzard MountJournalDocumentation.lua mirrored at
https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/MountJournalDocumentation.lua

Art: generated with the built-in image tool from the approved Peon Messenger concept. Production prompt:
blank textured parchment and friendly hooded peon in a bronze portrait frame, no text or seal,
alpha-transparent background. Separate prompt: blank matte burgundy wax seal, alpha background.
`assets/Build-PopupAssets.ps1` converts these PNG sources into power-of-two 32-bit alpha TGA textures.
`assets/build-ding-sounds.js` reproducibly synthesizes the original quiet WAV samples. Ding.wav is the
draft warm chime; DingBell.wav and DingWood.wav are audition alternatives, not enabled defaults.

Validation: run `node tests/run.js` under the normal Windows user profile for DPAPI tests as well.
The new Lua tests exercise filtering, freshness, guild membership, duplicates, saved options, local
previews, existing mount baselines and first-acquisition behavior. Actual in-game visual and sound QA
is performed by the player through `/lootbot options`; the test suite does not control the game.


Portrait polish: loot and mounts use a circular masked icon under PingPortraitRing.tga (64 KiB).
Source: assets/PingPortraitRing.png, generated with the built-in image tool. Prompt: centered,
weathered bronze circular portrait ring, dark inner bevel, restrained gold highlight, transparent
center and exterior, no text, icon or ornaments; readable at 110 pixels. The original peon is unchanged.
Stamp motion uses a fixed anchor with a centered animated child: 160 ms accelerating press from
128% to 96%, then a 140 ms eased settle to 100%. Animation-off snaps to the final pose.
Easing reference: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/easing-function/cubic-bezier
