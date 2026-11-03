# Original Formalities Weekly: the full paper

Open the minimap newspaper button or `/lootbot newspaper`. Previous and Next
sit beneath the paper, with a page number. The wheel still zooms; drag pans
the enlarged page, or moves the fitted paper. Changing pages resets pan and
zoom. X and Escape close it. The first-week welcome cover also has a back page.
`/lootbot newspaper demo` previews a four-page issue using explicitly labelled
invented figures. It does not write demo readings, mark real issues as read,
or send anything to guild members or Discord.

The real paper has a front page, optional inside sections and a back page.
Two old Western broadsheet front layouts rotate, with a blackletter masthead,
engraved Horde illustrations, narrow text columns and fictional advertisements.
Actual names and figures are typeset by the addon, never painted into the art.
Large inside-page callouts make the guild numbers easy to find among the ads.

Monday 00:00 UTC starts a new publication window. The designated publisher
character prints automatically while in game, after a short synchronization
period. The front page prints the actual publication date. Reopening later
does not change it. A late publisher login can therefore produce a later date.
Once published, the pages and figures are frozen; late reports wait for the
next paper. All members need addon 0.4.1 for this shared-copy behavior.
After the first collection week, even a week with no readings gets a fresh
Monday front/back issue. Missing reports are not replaced with older figures.

## Where the data lives and who prints it

Statistics currently live in each participating addon's LootBotDB, written to
WoW's SavedVariables file at logout or `/reload`. Addons exchange snapshots and
cached readings through guild addon messages while members overlap online.
There is no statistics/newsletter upload to the Cloudflare D1 database. That
shared service still handles Discord loot and level announcements separately.

The relay executable can therefore be offline all weekend. Other guild addons
continue collecting and sharing. The first configured relay character becomes
the pinned publisher (`/lootbot relay on` is the normal relay setup command).
The publisher automatically builds one issue each publication week, freezes
the actual page text, and distributes the same payload through guild messages.
Readers choose bundled artwork and overlay the frozen text using font strings.
No image-generation service runs then; the illustrations, ads and layout plates
are already installed. `/lootbot newspaper status` shows the publisher and latest
available paper. Other relay characters do not replace a pinned publisher.

If the publisher is offline at the boundary, printing waits for that character
to log in. The .exe is not needed for this. New readers can get a complete copy
from any online guildmate who has it, even after the publisher leaves. If no
copy-holder is online, receipt waits. Login is not an Internet download. The
transfer uses bounded chunks, a checksum and acknowledgments/retries; incomplete
or corrupted transfers do not become an issue. Four issues are retained locally.

The first minute allows reports and cached issues to arrive. Printing then
waits until incoming stats have been quiet for 15 seconds, up to ten minutes
after startup/week change. An existing announced issue is retrieved rather
than rebuilt. Published data and last-printed counter baselines travel together,
so a recovered publisher can resume without counting activity twice. The next
paper compares the newest known totals with the last printed totals; late
historical readings can therefore enter a later issue without editing the old
one. First-ever counters still establish a baseline, never lifetime-from-zero.

This is one publisher with trusted guild peer distribution, not an always-on
Cloudflare publishing service. SavedVariables writes occur at logout/reload,
so normal WoW persistence and crash limitations apply. A scheduled release
while the publisher never logs in would require an additional online service
and an inbound delivery route to the game; that is outside this build.

## When a story makes the paper

- The front page chooses an actual recorded highlight and rotates smaller
  reports among active counters. Empty counters and unknown values stay out.
- The Goblin Ledger can rank the largest reported purses and personal repair
  bills. Current money is a balance in copper from GetMoney, not lifetime gold
  earned or maximum gold ever held. Banks, items and hidden/unreported characters
  are not included. Only purses of at least one gold are candidates; unchanged
  leaders/balances stay out of subsequent issues unless a reported balance
  changes by at least one gold or the leader changes.
- World PvP uses Forever statistic **381, World Honorable Kills**. It does not
  substitute total or battleground honorable kills. The section needs activity.
- The level race uses reported UnitLevel values. It needs two reporting
  characters, somebody below 60 and fresh progress (or the first comparison).
  All-60 and quiet races are omitted. These are characters, not account-wide
  player rankings.
- If there is no ledger or road story, an inside page can explore active
  everyday guild counters. A quiet week can have just a front and back page.

The back page rotates clearly fictional regional weather, wireless listings
(the Azeroth version of "what's on TV"), letters and classifieds. Axe adverts,
goblin services and inn notices are flavour, not real offers or live game data.
The field notes are ordinary preparation reminders, not fabricated achievements.

## Confirmed repair spending

The checked Forever catalogue has no repair-spending row. NewsletterMetrics.lua
therefore observes the public RepairAllItems call through hooksecurefunc, without
calling, replacing or blocking it. It saves a repair payment only when both
the personal money decrease exactly matches the earlier vendor quote and the
repair quote clears. Repeated notifications do not count twice. Guild-funded,
failed, ambiguous and single-item repairs are excluded. Tracking starts when
this addon version is installed; it cannot recover old repair bills.

Money, level and repairs use internal transport IDs 900001–900003. These are
LootBot fields, not achievement IDs. They use the existing bounded guild-only
snapshot transport and never trigger the optical loot marker. Profiles work
even if a client lacks the Forever statistics catalogue. Protected/unavailable
API values remain unknown. The normal 30-minute capture interval still applies.

Edition pages are cached by weekly bucket and data revision, so the minimap
badge does not rebuild the newspaper every half second. Network limits,
retention and casual catch-up rules are unchanged; see WEEKLY-GAZETTE.md.

## Sources and checks

- [Blizzard's published Statistics frame source](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Statistics/Camelot/StatisticsFrame.lua)
- [Blizzard's merchant UI source](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/MerchantFrame.lua)
- `docs/data/forever-statistics-1.60.1.70338.json` records the build-matched IDs.
- Fonts are bundled with their SIL Open Font Licenses from Google's fonts
  repository. The body uses Crimson Text; mastheads use UnifrakturMaguntia.

`tests/render-newspaper-pages.ps1` exports actual Lua page text using invented
sample characters and renders standalone typography proofs. Those sample names
and numbers are not shipped as live content. Automated tests cover page bounds,
dates, relevance, world-only PvP, wealth formatting, repair confirmation and
guild transport. Actual rendering and repairs still need a live game check.
