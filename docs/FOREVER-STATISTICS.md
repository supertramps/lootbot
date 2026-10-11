# Forever statistics data

The build-matched catalogue contains 201 statistic definitions from beta
1.60.1.70338, the version installed locally on 11 October 2026. Both
[JSON](data/forever-statistics-1.60.1.70338.json) and
[CSV](data/forever-statistics-1.60.1.70338.csv) contain IDs, English labels,
category IDs/names, parent categories, flags and ordering. These are definitions;
they do not contain anyone's character values.

Definitions come from the client Achievement and Achievement_Category tables:

- https://wago.tools/db2/Achievement/csv?build=1.60.1.70338
- https://wago.tools/db2/Achievement_Category/csv?build=1.60.1.70338

The access pattern was checked against Blizzard's own Forever UI code:
https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Statistics/Camelot/StatisticsFrame.lua

The addon enumerates `GetStatisticsCategoryList()`, obtains each category's
entry count with `GetCategoryNumAchievements(categoryID)`, then reads
`quantity, skip, statID = GetStatistic(categoryID, index)`. Names come from
`GetAchievementInfo(statID)`. This is data returned by WoW's Lua API; no image,
screen, memory inspection or web call is involved in collecting character
statistics.

The API quantity may be a string. The probe preserves it in `value` and stores
`numericValue` only when `tonumber` succeeds. Currency/icon strings and other
formats are not guessed. Blizzard's panel displays `--` when the returned
number is zero or nonnumeric; a real API zero therefore remains a known zero
in LootBot. Missing/protected values remain unknown, and hidden rows are tagged.

`/lootbot stats` captures this character's exposed catalogue and values into
`LootBotDB.statisticsProbe`. Opening the newspaper also captures them. WoW
writes that SavedVariables snapshot on reload or logout, making it available
for a later local JSON/CSV export. Nothing is sent to the relay or guild by
this module.

The personal edition selects corpse runs and death causes, completed quests,
creature kills, epic loot, legendary acquisitions, largest hit/heal, recorded
boss kills, need rolls, health potions, fishing, critters, hugs, waves and
facepalms. They are labelled lifetime totals. Boss totals cover readable,
visible boss counters only. Missing counters show `--`.

Weekly results require dated snapshots and a baseline; maximum-hit statistics
cannot be treated as an additive weekly count. Guild rankings require member
snapshots and syncing. A player's live API catalogue remains authoritative if
the beta changes its definitions or filters entries. This integration still
needs a live capture from the current beta character; automated tests verify
format handling and UI behavior with mocks.
