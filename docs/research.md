# Research notes — guild relay and level milestones

Researched 22 September 2026. These sources inform the implementation; old forum numbers are not treated as current API limits.

## Level notifications: direct events over roster polling

[GuildNotifications](https://www.curseforge.com/wow/addons/guildnotifications), by its author JCBasso, already offers configurable milestone-level alerts for Classic. This confirms that the feature has precedent; it does not prove our implementation works in a particular future client.

[Blizzard UI source using PLAYER_LEVEL_UP](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_OverrideActionBar/OverrideActionBar.lua) consumes the event's new level rather than relying solely on `UnitLevel`. LootBot likewise records the event argument on the player's own client. Tests deliberately leave the mocked UnitLevel unchanged while delivering a new-level event.

Guild roster data can provide member names/current levels and can be compared over time, but that comparison does not establish exactly when an absent member crossed an intermediate milestone. It also needs a baseline to avoid greeting every existing member with a fake level-up on first install. Since every participating friend installs LootBot, the direct event gives a better event history. We use the roster only to validate that incoming addon messages come from current guild members.

The addon author's [GuildPlus announcement and discussion](https://www.reddit.com/r/wowaddons/comments/1rvrsu7/enhance_your_guild_experience_with_guildplus/) describes similar guild level/milestone notifications. That is useful product precedent, not a dependency or guarantee about our networking.

## Addon-to-addon communication

[Classic Era ChatInfo API source](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua) documents registered prefixes and `C_ChatInfo.SendAddonMessage`. LootBot registers `LootBot2`, advertises relays on GUILD, and transfers events/acknowledgements through WHISPER to a recognized guild member. It does not print sync data into ordinary guild chat.

The first-hand [“How to view CHAT_MSG_ADDON” discussion](https://www.wowinterface.com/forums/showthread.php?t=46118) covers prefix registration, receiving addon messages, and authors encountering throttling. The [“AddonMessage Flooding/Mass Disconnects?” discussion](https://www.wowinterface.com/forums/printthread.php?t=57709) is a particularly relevant caution against bursty guild-wide fan-out.

Implementation: one bounded outgoing queue per client, a minimum 0.5-second send interval, payloads capped at 230 bytes, staggered offers, and stop-and-wait delivery with matching event-ID acknowledgements and retries. These are conservative implementation choices, not claimed Blizzard guarantees. The test simulation drops an acknowledgement and verifies retransmission without duplicate inbox records.

The [addon-author discussion of selecting one announcer](https://cdn.wowinterface.com/forums/showthread.php?t=59020) outlines keeping a list of participating clients and choosing one deterministically. LootBot uses a similar character-name election as a collision guard. This is not sufficient for cross-computer Discord delivery deduplication; handovers must transfer the desktop ledger.

## Persistence, summaries and transport limits

Addon events retain source timestamps and stable character/event identifiers in SavedVariables. A returning relay asks each member for history after its last stored cursor. If that cursor is no longer present, the member replays retained history and the relay deduplicates it. Guild identity separates histories when changing guilds.

The addon acknowledgement confirms receipt in the relay's in-memory addon inbox, not delivery to Discord or a completed disk save. SavedVariables persistence still depends on logout/UI reload. Desktop events are separately journaled to disk before sending; successful and uncertain delivery states persist through restart.

[Discord webhook API](https://github.com/discord/discord-api-docs/blob/main/developers/resources/webhook.mdx) supports posting embeds without a full bot account. The helper uses confirmed responses (`wait=true`), suppresses mentions, respects explicit rate limits, and holds ambiguous failures instead of blindly retrying. A custom bot account is not required for this version.

The addon still cannot make its own HTTP request. The optical bridge remains one-way and depends on a visible, unobscured game. The new marker is 128×16 pixels, relay-only, hidden between transmissions, and repeated three times per record. `/lootbot sync` replays retained data if captures were missed. Shrinking it to one-pixel cells needs live validation on the actual display configuration despite passing synthetic bitmap and scale tests.

## Validation and remaining live checks

- Automated tests cover real Lua encoding/parsing, translated loot templates, private-member mode, offline member sync, lost-ACK recovery, membership checks, milestone deduplication, replay, digest timing, persistent delivery history and Discord size limits.
- Windows tests cover the actual pixel decoder using generated bitmaps and DPAPI interoperability between the tray app and the helper.
- The tray app is visually inspected and smoke-tested in Preview. No automated test sends a guild or Discord message.
- Still required: two live Classic guild clients, actual milestone event, the smaller marker on the user's display, and any future Forever client.

The live 0.1 prototype already detected actual loot and generated messages. That does not replace live validation of the new guild protocol and compact marker.
