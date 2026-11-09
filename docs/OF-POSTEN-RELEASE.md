# OF-Posten 0.4.6

Swedish fixed newspaper art and copy, with Poseidon, the tram and Älvsborgsbron reimagined in Azeroth. Approved front-page copy is in OF-Posten-SPEC.md; later user changes remove advertisement disclaimers and the Monday promise on the welcome page.

Right-click minimap > options > Crimson / Trycksvärta / WoW opens a local dummy edition with that font. No stats are submitted, shared, or replaced. Crimson remains the production body font. The newspaper fits 90% of UI height without the old 515-unit cap.

Active textures keep existing filenames: NewsletterFront1.png, NewsletterFront2.png, NewsletterInside.png, NewsletterBack.png, NewsletterWelcome.png. Both front rotations currently share the approved Poseidon artwork. Source PNGs live in assets/newsletter/of-*.png; Build-ClassicTexture.ps1 produces padded 2048-square game textures. Front coordinates are adjusted to its new artwork; stats calculation and publication transport are unchanged. Existing published statistics text remains unchanged per specification.

Upload the addon-only ZIP to CurseForge. The ZIP contains LootBot/ at its root. No SavedVariables are included. Existing users update normally, then restart/reload WoW. A fresh restart is safest for textures cached by the client. This package has not been uploaded to CurseForge automatically.

39 automated tests pass, including local preview controls, reading-state preservation, navigation and stats regressions. Final game typography review is done using the local preview buttons.
