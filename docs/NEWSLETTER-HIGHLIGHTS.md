# Requested highlights for Monday 9 November 2026

Need rolls (1044), total killing blows (1487), and duels won/lost (319/320) are included in publication
readings and two recurring feature pages whenever meaningful data exists. These pages use explicitly
labelled lifetime character totals, rather than presenting first readings as a week's gains. Duel
rows require both values; zero losses display unbeaten, not division by zero. Rows sort by wins, then
fewer losses, then character name. The page prints W/L and win percentage, not an invented kill/death ratio.

The saved statistics store on the relay PC was empty on 8 November although a personal API probe and
loot history existed. StatisticsSharing still used UnitName's first return as the character name;
Forever's surname-aware roster rejected this as the own player. This now uses Protocol.localPlayerName
and Protocol.canonical like loot sharing. New statistics support requires members to update and log in.
`/lootbot newspaper status` now reports how many character checkpoints are available.

Gold deposits use a read-only snapshot of the guild-bank money log, automatically requested while
the user opens the guild bank. `/lootbot bank` requests a refresh while it remains open. Only direct
deposit rows count; withdrawals, repairs, purchases and system deposit summaries do not. Snapshot
refreshes replace rather than accumulate, preventing duplicate totals. The publisher uses its own
snapshot when building the shared edition; no extra bank transport or account credentials are used.

The printed donation leaderboard explicitly says it covers the latest visible bank log, filtered to
the issue's period using the API's approximate elapsed time. It is NOT a complete weekly/lifetime
donation ledger: older entries can roll off before observation. Unavailable or empty data omits the
section rather than publishing zeros. Open the guild bank on the publisher before the Monday issue
is frozen. Bank permissions and Forever behavior still require in-game verification.

API reference: Blizzard's bank UI queries and reads the money log using the native globals:
https://github.com/tomrus88/BlizzardInterfaceCode/blob/master/Interface/AddOns/Blizzard_GuildBankUI/Blizzard_GuildBankUI.lua

Publication remains Monday 00:00 UTC (01:00 Stockholm in November), when the designated publisher
is online and the existing synchronization grace period has finished. An offline publisher releases
on its next login. Frozen editions are not silently rewritten by this change. New feature copy is
Swedish; the full Originalbladet artwork/translation refresh is still a separate outstanding task.
