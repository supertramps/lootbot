# Guild Gazette Classic preview

This branch adds a newspaper to the Classic and Forever LootBot addon. It
uses this character's statistics when the client exposes them. On clients
without readable statistics, it shows a labelled sample issue. Newsletter
syncing and weekly guild results are still to be implemented.

The manifest targets Classic Era (11509) and the Forever beta (16001). For
Forever, install into `_classic_beta_/Interface/AddOns/LootBot` and restart the
client after changing the manifest. The personal newspaper's live API values
and Forever relay compatibility need in-game checks.

After installing the addon and reloading WoW, click the note icon by the
minimap or type `/lootbot newspaper`. Only the paper and a small X are visible.
Use the mouse wheel to zoom. Drag to move the paper at its fitted size, or pan
the page when zoomed in. Escape also closes it. The red `1` badge is a sample
new-issue notification and disappears when the issue is opened.

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

The paper art stays installed while the text changes. Guild syncing and weekly
issue generation are not part of this preview. See `FOREVER-STATISTICS.md` for
the complete build-matched catalogue and API details.
