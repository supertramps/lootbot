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

The relay character pinned as publisher runs the newspaper commands.

- `/lootbot news sync` asks online guildmates for fresh readings. After 60
  seconds, the publisher gets a receipt. Run `/lootbot newspaper coverage` to
  see whose readings are saved.
- `/lootbot news preview` typesets a private draft from saved readings.
- `/lootbot news publish` freezes the page text and figures and sends the issue.
  Readers get a minimap badge when they have a complete copy.

## Where the data lives and who prints it

The publisher's readings and last printed totals live in LootBotDB. WoW writes
this data to SavedVariables on normal logout or /reload. Repeated syncs update
the latest reading. Publication advances the baseline. A character's first
reading establishes a baseline for cumulative counters.

Guildmates send readings privately to the publisher and receive the same
finished pages. They need addon 0.4.22 or newer. A member who was offline can
receive the finished issue from any online guildmate who has it. The newsletter
runs through guild addon messages and bundled artwork. The desktop relay and
Cloudflare still handle Discord announcements separately.

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
