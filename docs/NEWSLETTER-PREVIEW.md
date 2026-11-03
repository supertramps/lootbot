# Original Formalities Weekly beta preview

This branch adds Original Formalities Weekly to the Classic and Forever
LootBot addon. It collects character API statistics and shares guild readings.
The first week shows a finished welcome cover. Newsletter
syncing and weekly guild results are now included. See WEEKLY-GAZETTE.md for
the transport, weekly coverage and counter rules. The first week displays a
welcome front page while members build their baselines.

The manifest targets Classic Era (11509) and the Forever beta (16001). For
Forever, install into `_classic_beta_/Interface/AddOns/LootBot` and restart the
client after changing the manifest. The personal newspaper's live API values
and Forever relay compatibility need in-game checks.

After restarting the client once to load the new modules, click the round
bronze newspaper icon by the
minimap or type `/lootbot newspaper`. A small X closes the paper; Previous and
Next beneath it change pages. `/lootbot newspaper demo` opens a full dummy-data
issue without modifying or sharing real guild statistics.
Use the mouse wheel to zoom. Drag to move the paper at its fitted size, or pan
the page when zoomed in. Escape also closes it. A gold exclamation mark signals
an unread welcome cover or completed weekly issue and disappears when opened.

Run `/lootbot stats` to read this character's exposed statistics. The command
prints the number of entries and populated values. Run `/reload` afterward to
save `LootBotDB.statisticsProbe` in the beta's SavedVariables file. Missing
values such as `--` stay unknown. This command never sends statistics to other
players, the desktop helper, or Discord.

The editable source artwork is `assets/newsletter/newspaper-front-page-template.png`.
The text placement map is `assets/newsletter/newspaper-front-page-layout.json`.
`assets/newsletter/Build-ClassicTexture.ps1` produces the power-of-two PNG in
`addon/LootBot/NewsletterPage.png` for WoW. The sample and personal edition
layouts live in `addon/LootBot/NewsletterPreview.lua`.

Two Western-style Horde fronts, an inside section and a classifieds back page
are bundled as NewsletterFront1/2.png, NewsletterInside.png and NewsletterBack.png.
A separate NewsletterWelcome.png remains the first-week cover. Crimson Text
and UnifrakturMaguntia fonts are bundled with their open licenses. Actual figures
are typeset around fictional notices and engravings. The artwork stays installed
while text changes. See NEWSPAPER-PAGES.md for dates, sections and data coverage.
StatisticsSharing.lua captures API readings at login and every 30 minutes and
shares them through guild addon messages, independently of the optical relay.
`/lootbot stats off` pauses sharing; `stats on` resumes it. Multiplayer delivery
and visual rendering still need live beta verification. See
`FOREVER-STATISTICS.md` for the complete build-matched catalogue and API details.
