# Uppdrag till Codex Astra: Uppdatera OF-Postens fasta texter

## Bakgrund och mål

Projektet innehåller en redan existerande tidningslayout för guilden **Original Formalities** i *World of Warcraft*, med göteborgsk lokalprägel och utseende som en gammal västern-/1800-talstidning.

Tidningen ska heta **OF-Posten**. Uppgiften är att ersätta den **fasta redaktionella texten och annonsernas text** enligt specifikationen nedan, utan att förändra någon av de automatiskt genererade statistiksektionerna.

Språket ska vara naturlig svenska, med lätt göteborgsk humor och diskreta WoW-referenser. Undvik svengelska, krystade skämt och ordet **”horden”**. Följ de godkända texterna ordagrant; skriv inte om dem utan att fråga.

## Arbetsinstruktioner

1. Undersök projektets befintliga kod, komponenter, mallar och eventuella bild-/textlager. Identifiera var de fasta texterna faktiskt kommer från.
2. Genomför ändringarna i **källan som används vid generering**, inte enbart i en tillfällig förhandsvisning. Om någon text är inbakad i en bild eller genereras genom en prompt, identifiera det och uppdatera den relevanta källan på ett sätt som bevarar övrig grafik.
3. Ändra **endast** de listade fasta texterna. Behåll layout, pappersstruktur, sepiafärger, ramar, illustrationer, placeringar och övrig typografi så långt möjligt.
4. Alla statistikfält, deras dataflöden, beräkningar, rubriker och renderingslogik ska lämnas **oförändrade**. Fyll inte tomma stora rutor med ny text.
5. Anpassa endast textens radbrytning och, när det verkligen behövs, dess lokala storlek eller radavstånd för att undvika överlappning eller klippning. Om en godkänd text inte får plats utan påtaglig designändring: rapportera hindret i stället för att själv korta eller skriva om texten.
6. Kontrollera att svenska tecken och särskilt **ô** i **GÔTT** återges korrekt. Bevara stavning, interpunktion och versalisering enligt nedan.
7. Gör inga orelaterade refaktoreringar eller ändringar i projektets funktionalitet.

## Godkända textändringar

### 1. Huvudtitel – stora titelrutan högst upp i mitten

**OF-Posten**

Använd detta namn konsekvent i projektets fasta tidningstexter där det gamla tidningsnamnet förekommer. Den grafiska sättningen får använda versaler (**OF-POSTEN**) om det passar rubrikens befintliga stil.

### 2. Övre vänstra hörnrutan

**FÖR GÔTT FOLK & GÔTT TJÖT**

Ersätter den gamla parollen, inklusive eventuell text med ”horden”.

### 3. Övre högra hörnrutan

**TRYCKT I ORGRIMMAR**

### 4. Bildtext direkt under den stora mittillustrationen med tidningsläsande orch

**En stilla förmiddag på Götaplatsen i Orgrimmar.**

### 5. Den horisontella remsan ”Från anslagstavlan”

**Rubrik:** FRÅN ANSLAGSTAVLAN

**Notis:** Upphittad hjälm. Ägaren ombedes beskriva bucklorna.

### 6. Stor yxannons till höger – Gruk & Söner

**Företagsnamn:** GRUK & SÖNER

**Stor rubrik:** EN REDIG YXA

**Brödtext:** Hugger ved, ben och annat bråte. Gruk & Söner.

### 7. Liten fiskeannons till höger, under yxannonsen

**Rubrik:** FISKESÄLLSKAP SÖKES

**Brödtext:** Eget spö medtages. Murlocs göre sig icke besvär.

### 8. Nedersta annonsraden – sex annonser från vänster till höger

| Position | Rubrik | Brödtext |
|---|---|---|
| 1 – goblin/kassabok | **ORDNING PÅ GULDET** | Vi räknar. Du betalar. |
| 2 – värdshus/boende | **RUM UTHYRES** | Torrt under tak. För det mesta. |
| 3 – stövlar/skomakare | **NYA SULOR** | För den som gått hela vägen till Barrens. |
| 4 – spårvagn | **ORGRIMMAR-SPÅRVAGNEN** | Går den, så går den. |
| 5 – bro | **ÄLVSBORGSBRON** | Härifrån ser man ända till Kalimdor. Nästan. |
| 6 – Poseidons värdshus | **POSEIDONS VÄRDSHUS** | Öl, käk och gött tjöt. |

Illustrationerna för respektive annons ska behållas.

## Godkända längre texter – referensmaterial, INTE för placering nu

Följande tre texter är godkända redaktionella texter för ett **möjligt framtida** insändar-/notisformat. **Infoga dem inte i den nuvarande tidningssidan, skapa inga extra rutor och använd inte statistikytorna för dem.** De finns med här för att dokumentera besluten.

### Insändare: DET ÄR SMEDEN SOM BLIR RIK!

Bäste redaktör!

Vi slåss mot drakar och annat elände vecka ut och vecka in. Lik förbaskat är det smeden som tjänar mest på våra bedrifter.

Snart kostar det mer att laga rustningen än att köpa en ny.

*– En fattig krigare*

### Lokalnotis: MÄRKLIG FÅNGST I GÖTA ÄLV

En fiskare från Majorna drog under gårdagsmorgonen upp en murloc ur älven.

Fångsten väckte stor uppståndelse på kajen och har sedermera förts till Feskekôrka för närmare undersökning.

Fiskaren själv vägrar gå ut med båten igen.

### Lokalnotis: DVÄRG GRIPEN VID HAMNEN

En misstänkt dvärg från Ironforge greps under natten sedan han försökt sälja kartor över Orgrimmar till stadens egna vakter.

Dvärgen hävdar att allt var ett missförstånd.

## Kvalitetskontroll och leverans

- Kontrollera ändringarna i det befintliga renderings-/genereringsflödet, om detta är tillgängligt i projektet.
- Säkerställ att samtliga fasta texter syns inom sina ramar och att rubriker inte krockar med illustrationer.
- Verifiera att **alla statistikfält och deras automatisering är oförändrade**. Några stora tomma rutor i mallen är avsiktligt reserverade för statistik.
- Sök efter äldre förekomster av **Original-Posten** och ersätt dem med **OF-Posten** i relevanta fasta tidningstexter. Ändra **inte** guildens namn **Original Formalities**.
- Sök efter kvarvarande fasta fraser med **”horden”** i själva tidningsmallen och rapportera eventuella träffar som inte omfattas av ovanstående ändringar; gör inga andra automatiska ersättningar utanför de godkända fälten.
- Redovisa vilka filer du ändrade och ge en kort sammanfattning av resultatet samt eventuella begränsningar.

**Prioritet:** Korrekt text och intakta statistikfält väger tyngre än kosmetiska förbättringar.
