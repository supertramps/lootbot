# Original Formalities Weekly

Every guild member installs the same addon. It reads their own statistics from
the game's API at login, every 30 minutes online and at logout, then shares readable
numeric counters through guild addon messages. It never reads the statistics
screen. No desktop helper, optical bar, Discord webhook or cloud database is
used for this feature.

The guild's addons cache each other's readings. On login a client requests a
cache from the first guild peer that offers one, rather than requesting a full
copy from everyone. This can recover earlier readings for offline characters.
At least one online addon peer must have a saved copy. It is best-effort guild
messaging: missing chunks are repaired by a subsequent snapshot or cache
exchange, not guaranteed delivery. Different clients can temporarily show
different coverage until they sync.

Weeks begin Monday at 00:00 UTC. A new week's baseline is the last known
reading, even from an earlier week. The latest reading is the end. Any missed
activity counts in the week it is discovered; this is a casual guild paper,
not an exact calendar audit. The paper shows the previous
week if available, otherwise the most recent retained week. During the first
week a welcome front page invites members back for Monday's first issue.
Figures are recorded changes, not exact full-week activity. First-ever readings
establish a baseline without counting lifetime totals. Missing values are not
zero, and a counter falling below its baseline is omitted. Last-known numeric
readings survive long breaks, pruning and addon restarts. Repeated readings
do not double-count catch-up. Four weeks of newspaper history are retained,
with up to 100 characters per weekly bucket, scoped by guild and realm.
Persistent checkpoints hold at most 100 characters and 500 counters each.

Three columns rotate among death causes/Hogger, quests/loot/kills/potions,
and fishing/critters/emotes. Selection prefers counters with activity, so a
stat may recur if it is the only active one in its group. Top three players
and guild totals use weekly deltas. Names omit realm suffixes on the page.
A standout player and number becomes the headline. A newly improved biggest
hit or heal can take the headline; its absolute record is shown, not a sum or
weekly difference. Guild rankings are per character, not per human account.

Three restrained Horde art templates rotate by week: War Camp, Totem Post, and
Ashen Dispatch. A separate finished welcome cover has no stat boxes. Text changes
in game without downloading new art. The round
minimap button uses Blizzard's circular portrait and bronze tracking rim.
An exclamation mark signals the unread welcome cover or a completed week,
with read status saved per character.
Click to read; mouse wheel zooms, drag pans/moves, X or Escape closes.

`/lootbot stats off` pauses collection/sharing; `stats on` resumes it. Already
shared readings remain cached by peers. `/lootbot stats` is still a manual
local API inspection. `/lootbot newspaper` opens the latest available edition.
The sample issue is only a labelled fallback when there is no readable data.

Transport messages are at most 255 bytes, with one queued data packet every
half second per client. Reassembly expires after two minutes and is bounded
to 32 assemblies and 100 chunks each. Unknown guild senders, future dates,
cross-week records, malformed numbers and oversized catalogues are rejected.
Guild members are trusted participants: this is not an anti-cheat system.

Automated simulations cover out-of-order and repeated chunks, three peers,
offline cache transfer, weekly baselines, record headlines, resets, rotation,
membership/time validation and absence of optical traffic. Validate actual
API counters and bronze-rim rendering in the beta, then run with two guild
characters before treating the preview as a production guild feature.

The newspaper uses clean Crimson Text regular and semibold fonts, bundled
under the SIL Open Font License. Font source:
https://github.com/google/fonts/tree/main/ofl/crimsontext
