# 0.4.7 — data-first OF-Posten
WoW font for all printed text. One local dummy newspaper button. Demo publication date is the current date; live publication dates remain frozen at actual publication.
Added raw activity IDs 94, 346, 347, 349, 353 and profession IDs 281,1519,1524,1527,1532,1535,1536,1537,1538,1541,1542,1544 to publication selection. Raw capture already enumerates these statistics. Unknown values stay unknown; activity cards require a positive measured delta. Primary profession fields are historical highest skill, explicitly labeled.
Data ledger, stacked stories, six-card activities and twelve-profession final page replace repeated decorative layouts. Reuses an unprinted portion of existing texture: no added image weight. Quest remains quest.
All readers/publishers need 0.4.7 for new layout names. Existing frozen issues retain their printed layout until a new edition is published. No automatic rewrite of stored editions.
39 tests passed, including raw-value examples, missing-data behavior, preview date, page navigation and publication serialization roundtrip. In-game visual review remains manual via options > Visa provtidning. No game input automation used.
Addon-only ZIP prepared; not uploaded to CurseForge.
