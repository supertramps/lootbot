# LootBot 0.3: shared guild relay

## TL;DR — zug zug

Friend installs addon. Friend loots good gear or dings a milestone. Addon tells a guild relay; no extra program or flashing bar for friend.

Relay volunteer runs addon **and** LootBot.exe. Their tiny bar flashes for qualifying events. Program reads bar and sends news to the shared service. Service remembers what it has seen and posts to Discord once.

No relay online? Addon keeps the news until friend and relay are online together. Each character can use `/lootbot filter rare` or `/lootbot filter epic`; at level 40, only epics and above go through. Grey, white, and green loot never goes through. Zug zug.

## Friends

Install the LootBot addon from the addon ZIP into your Classic client's Interface/AddOns folder. Restart WoW after installing. Everyone must update to 0.3: older versions do not use the same relay announcement protocol.

Play normally. Your addon records your own loot and level milestones (10, 20, 30, etc.), and shares them privately with available guild relays. You see no pixel strip and need no desktop program. Records transfer while you and a relay are online together. SavedVariables are written at logout or /reload; a crash can lose unsaved records.

## Relay volunteers

Extract the whole Windows relay ZIP into a writable folder, then open LootBot.exe. No Node installation or terminal is needed. Install the same 0.3 addon too.

Click **Relay registration**, copy the public registration, and send it to your guild's LootBot administrator. They approve it through **Tools > Add relay**. Each computer gets its own encrypted identity. Do not copy someone else's relay-identity.json or webhook.dpapi.

Choose Live and Start relay, then use `/lootbot relay on` in WoW. Start the app before logging in, or use `/lootbot sync` after starting it. The app can hide in the system tray. WoW must remain visible so its small pixel strip can be read.

Several approved relays can run together. Each sends event records to the shared Cloudflare service. The service remembers the event ID and posts each event once under normal operation. Switching relays no longer requires copying delivery history. Two or three volunteers are ample for this guild; the free hosting plan has usage limits.

## Tests and personal filters

Open **Tools**. WoW can be completely closed; the relay capture does not need to be started.

- Enter any valid **Classic item ID**, then Preview item or Send item test.
- Select a milestone level from 10 through 60, then Preview level or Send level test. Messages grow more celebratory at each milestone; level 60 gets a gold card and a short, excited line. Even an older level-60 record receives its own announcement instead of being buried in a catch-up summary.
- Preview catch-up or Send catch-up to see an example with nine made-up records from three players. The preview is immediate and does not post; the sent test uses the same condensed format as an actual backlog.
- Item and level tests show **LootTester** in the same style as real events, without a test footer or prefix. Catch-up examples use LootTester, LootTesterTwo, and LootTesterThree. Tests bypass item filters. Player realms stay in internal event IDs for duplicate detection but are omitted from Discord messages.
- Preview never posts. Sending after a preview keeps the selected title. Preview again to roll a different title.
- Each character chooses its own loot threshold in WoW: `/lootbot filter rare` sends blue, purple and legendary drops; `/lootbot filter epic` sends purple and legendary drops. New characters start at Rare.
- At level 40, that character permanently switches to Epic and above. Grey, white and green loot is always discarded before it is saved, sent to a relay, or shown in the pixel strip. A high-level relay still forwards a low-level friend's qualifying blue drop.
- Tools keeps a shared **Blocked IDs** list as a final guild-wide veto. It cannot override a character's personal filter. Rarity is no longer configured in Tools.
- **Discord name** sets the sender name shown on new messages. It starts as LootBot and is shared across relays. You can also name the webhook in Discord, but LootBot's message setting controls the name when it posts.
- Filters affect new or still-pending announcements. Changing a filter does not repost previously filtered or delivered records.
- Tests and shared-filter changes require the administrator's registered app in this release. Other volunteers can collect and upload events.
- **Service status** shows whether Discord is configured and counts pending, sent, filtered, or uncertain events.

Normal loot messages have twelve title variants for each rarity, a Wowhead Classic link, and an item icon when Wowhead provides one. They omit item-ID fields and detection footers. Wowhead outages do not stop ordinary loot delivery; an uncached manual item test needs a successful lookup. Catch-up summaries show a compact selection of items rather than a separate icon for every event.

The addon records only loot that qualifies for that character. If item quality is briefly unavailable, it waits for item data rather than guessing and transmitting it. Existing older addon versions may still send junk through guild messages, but updated relays discard sub-blue loot before rendering it.

## Catch-up and reliability

Old events wait two minutes before the first catch-up summary; later summaries are at least fifteen minutes apart. Each summary lists every included event, with levels first (highest first), then loot by rarity. Large backlogs are divided into later summaries instead of showing an unexplained “+more” count. A one-minute cloud timer handles delivery even after the desktop apps close. Active apps also wake the sender, so queued messages do not have to wait for the timer.

The addon retains up to 30 days / 5,000 own events per character and 25,000 received events. The service keeps successful and filtered delivery records for at least 31 days. A late friend's records arrive when they next overlap with a relay online. A covered/minimized game can hide optical transmissions; `/lootbot sync` replays retained events safely.

A Discord timeout can occur after Discord accepted a message. Such events are marked **uncertain**, not automatically reposted. The administrator should check the channel before deciding to retry. This is not an absolute exactly-once guarantee across Discord and the database.

## Administrator setup

The service is the **lootbot** Worker with the **lootbot** D1 database bound as **DB**. The desktop service URL is in cloud-config.json. Discord's webhook belongs in the Worker's encrypted **DISCORD_WEBHOOK** secret, not in volunteer packages. The database contains only approved public relay keys; private keys stay encrypted on each volunteer's Windows account.

Developer deployment uses cloud/wrangler.jsonc, migrations/0001_init.sql, and publish.mjs. Publish imports the existing local delivery history and preserves the Cloudflare webhook secret; it does not replace it with the webhook saved on this PC. Run it only with the old relay stopped so history cannot change during handover. No paid plan is required.

Keep one backup of your original local state and your encrypted relay identity. Revoke a lost volunteer identity by setting its enabled field to 0 in the relays database table. Do not manually reset uncertain entries until checking Discord.

Automated tests cover simultaneous relays, offline sync, duplicate submissions, signed authentication, revocation, shared filters, previews, catch-up, rate limits, and uncertain sends. A live test with two WoW clients is still needed; Forever compatibility remains unverified.
