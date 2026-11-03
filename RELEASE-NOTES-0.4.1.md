Original Formalities Weekly now has multiple pages and one shared, frozen weekly edition.

- Two Western-style Horde front plates, illustrated inside sections and a busy classifieds back page.
- Previous/Next navigation, zoom/pan, actual publication dates and an unread indicator.
- Relevant reported gold balances, confirmed personal repair bills, world honorable kills, level progression and rotating everyday highlights.
- One automatic publisher character, with complete copies distributed through guild addons. Late reports enter the next paper instead of changing the published one.
- `/lootbot newspaper demo` previews made-up data without writing or sharing it. `/lootbot newspaper status` shows the publisher.
- Desktop all-loot testing and beta executable detection are included.

Install the whole addon and fully restart WoW once. All guild members need 0.4.1 for shared editions. Keep the publishing character configured with `/lootbot relay on`.

Monday starts a new publication window. The publisher must be in game to print; the first minute allows synchronization, followed by a quiet-data interval (up to ten minutes for busy sync). If the publisher is offline, printing waits for their next login. Once printed, an online guildmate with a complete copy can deliver it to later logins. The desktop .exe and Discord are not involved in newspaper delivery.

Statistics and newspapers live in WoW SavedVariables and travel through guild addon messages. This release does not upload newsletter data to Cloudflare D1. Repair coverage is confirmed personal Repair All payments recorded since installing this build; guild-funded, single-item and ambiguous payments are excluded.

Validation: 32 automated tests pass, including multi-peer frozen-issue delivery, lost fragments, publisher recovery, late-report carry-forward, dates, navigation and repair confirmation. Typography proofs use explicitly invented figures. Live multiplayer and repair compatibility still require in-game checks.
