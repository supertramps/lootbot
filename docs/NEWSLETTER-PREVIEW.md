# Guild Gazette Classic preview

This branch adds a visual-only newspaper test to the Classic LootBot addon. It
uses made-up names and numbers. It does not read character statistics, send
newsletter data, post to Discord, or change loot tracking.

After installing the addon and reloading WoW, click the note icon by the
minimap or type `/lootbot newspaper`. Use the `+` and `-` buttons to zoom, the
mouse wheel to scroll, and drag the page to pan. The red `1` badge is a sample
new-issue notification and disappears when the issue is opened.

The editable source artwork is `assets/newsletter/newspaper-front-page-template.png`.
The text placement map is `assets/newsletter/newspaper-front-page-layout.json`.
`assets/newsletter/Build-ClassicTexture.ps1` produces the power-of-two PNG in
`addon/LootBot/NewsletterPage.png` for WoW. The Classic preview text currently
lives in `addon/LootBot/NewsletterPreview.lua`.

Later, actual newsletter data can replace the sample values without replacing
the page art. Collection, guild syncing, issue generation, and Forever API
compatibility are not part of this preview.
