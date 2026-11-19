# Auftrag an Hermes, Teil 2: alles, was für ein perfektes NOIR LEDGER 4.0 noch fehlt

**Alles hier hat Priorität 1. Nichts auslassen, nichts vereinfachen.** Wenn etwas nicht machbar ist, in der
Abschlussliste genau sagen, was und warum.

Die erste Lieferung (Abschnitte 1–14, `docs/HERMES_ASSET_BRIEF_4.md`) ist vollständig eingebaut. Stil, Farben,
Inhaltsregeln (keine lesbare Schrift, kein Konsum, keine Waffen, keine echten Marken/Personen, eigenständig, nie wie
ein bestehendes Spiel), Lizenzregeln und technische Regeln aus **Abschnitt 0 und 0.1 des ersten Auftrags gelten
unverändert**. Lies sie vor dem Start noch einmal.

Repository `mrdevn4ever-sys/noir-ledger-ios`, Branch `claude/exciting-cori-5r0kcv`. Erst `git pull`, dann arbeiten.
**Kein Swift-Code**, keine Änderung an `scripts/`, `shared-assets/` oder bestehenden Dateien außer den hier genannten.
Der Paritätscheck `python3 scripts/shared_assets.py check` meldet inzwischen `ASSET_PARITY_OK` und muss das nach jedem
deiner Commits weiter tun.

Maße in Pixeln bei @3x. Imagesets wie gehabt: `App/Resources/Assets.xcassets/<Name>.imageset/<Name>.png` plus
`Contents.json` (`"idiom": "universal"`, ohne `scale`). Sprite-Blätter waagerecht, alle Bilder gleich groß, Figur in
jedem Bild an derselben Stelle, Blick nach rechts. Jede Datei in `docs/asset-credits.json`.

---

## A. Bewegte Etagen (wichtigster Teil)

Die Etagenplatten `Floor<Ware><0–5>` sind starr. Für jede der **24 Platten** eine Bewegungsebene, die **pixelgenau
auf die Platte passt**:

| Name | Maß | Inhalt |
|---|---|---|
| `Floor<Ware><Stufe>Run4` (z. B. `FloorWeed3Run4`) | 4 Bilder à **1206 × 588**, also 4824 × 588 | **Transparent bis auf die bewegten Teile** der jeweiligen Platte, exakt an derselben Stelle wie auf der Platte: Pflanzen wiegen sich, Blüten wippen, Wasser tropft aus dem Schlauch, Ventilator dreht (Gras); Kolben blubbern, Dampf steigt, Flüssigkeit fließt durch die Kühlschlangen, Kristalle funkeln auf dem Band (Crystal); Pressstempel geht runter und hoch, Tabletten fallen, Discokugel dreht, Band läuft, Neon flackert (Pillen); Waage schlägt aus, Presse drückt, Tresorrad dreht, Kronleuchter funkelt, Papier raschelt (Koks). Lichtkegel der Lampen leicht flackernd. |
| `Floor<Ware><Stufe>Lit` | **1206 × 588**, transparent | Nur das Licht der laufenden Etage: Lampen an, Lichtkegel, warmer Schein auf Wand und Boden. Wird über die Platte gelegt, solange die Etage arbeitet (ohne Arbeit bleibt die Etage dunkler). |

Wichtig: Schacht-Streifen links (0–162 px), Kisten-/Manager-Bereich (162–450 px) und Abzeichen-Bereich (ab 990 px)
bleiben in beiden Ebenen **völlig leer**, damit nichts die Bedienelemente verdeckt. Die Bewegung soll in 4 Bildern
nahtlos schleifen (Bild 4 geht weich in Bild 1 über).

Zur Kontrolle eine Vorschau pro Ware: `docs/asset-previews/FloorRun<Ware>.gif` (alle 6 Stufen untereinander, Platte +
Run4 + Lit übereinander, 6 Bilder/s). Die GIFs nicht in Assets.xcassets legen.

## B. Fenster im Cartoon-Stil (Bausatz)

Die Fenster (Aufträge, Kunden, Crew, Stadt, Kassenbuch, Shop, Kapitel, Einstellungen) nutzen noch die alten
Noir-Flächen. Dafür ein Bausatz aus **dehnbaren Teilen** (9-Slice): die Ecken bleiben fest, die Mitte und die
Kantenmitten werden gestreckt. Deshalb: **Mitte und Kantenmitten einfarbig bzw. nahtlos streckbar**, alle Verzierung
nur in den Ecken. Die Eckgröße steht in der Tabelle und muss eingehalten werden.

| Name | Maß | Ecken | Motiv |
|---|---|---|---|
| `SheetBackdrop` | 1206 × 1206, **Platte, nahtlos kachelbar in beide Richtungen** | – | Hintergrund aller Fenster: dunkles Nachtblau `#141A33` mit sehr dezentem Ziegel- oder Tapetenmuster (Kontrast höchstens 6 %). |
| `SheetHeader` | 1206 × 210, Platte | – | Kopf eines Fensters: Holzbrett mit Nieten, links und rechts kleine Laternen, Mitte frei für den Titel. |
| `PanelNight` | 300 × 300 | 60 px | Standardkarte: `#1E2648`, Kontur, oben heller Rand als Licht, kleiner Schatten. |
| `PanelPaper` | 300 × 300 | 60 px | Papierzettel `#F3E9D2` mit leicht gewellter Kontur, Reißzwecke oben links in der Ecke. |
| `PanelWood` | 300 × 300 | 60 px | Holzbrett (für laute Aufträge, Crew), Maserung nur in den Ecken, Mitte einfarbig `#7A4E2E`. |
| `PanelDanger` | 300 × 300 | 60 px | Rot umrandete Karte (`#E5484D`) für Warnungen, Mitte `#2A1A2E`. |
| `PanelGold` | 300 × 300 | 60 px | Goldener Rahmen für besondere Angebote (Shop, Finale). |
| `ButtonYellow`, `ButtonYellowPressed` | 300 × 150 | 60 px | Dicker Cartoon-Knopf `#FFC83D` mit dunklerem Unterrand (gedrückt: Unterrand weg, 6 px tiefer). |
| `ButtonGreen`, `ButtonGreenPressed` | 300 × 150 | 60 px | Dasselbe in `#3FC45A` (aufwerten, kaufen). |
| `ButtonGrey`, `ButtonGreyPressed` | 300 × 150 | 60 px | Dasselbe in `#6C7088` (gesperrt, ablehnen). |
| `ButtonRed`, `ButtonRedPressed` | 300 × 150 | 60 px | Dasselbe in `#D9433B` (riskant, Herausforderung). |
| `ChipPill` | 150 × 72 | 36 px | Kleine Kapsel für Hinweise, `#283259`. |
| `MeterTrack` | 600 × 48 | 24 px links/rechts | Leere Fortschrittsrinne mit Kontur. |
| `MeterFillGreen`, `MeterFillGold`, `MeterFillRed` | 600 × 48 | 24 px links/rechts | Füllung mit Glanzstreifen oben. |
| `SegmentTrack` | 600 × 108 | 54 px | Leiste für „×1 ×10 ×100 Max“. |
| `SegmentKnob` | 150 × 108 | 54 px | Gewählter Teil darin (gelb). |
| `ToggleOn`, `ToggleOff` | 156 × 96 | – | Schalter als Hebel (an: grün, Hebel rechts; aus: grau, Hebel links). |
| `TabBarPlate` | 1206 × 270, Platte | – | Hintergrund der unteren Leiste: Holzbrett über dem Bürgersteig, Oberkante mit Nieten. |
| `HudPlate` | 1206 × 360, Platte | – | Hintergrund der oberen Leiste: Nachthimmel-Stück mit Dachrinne unten. |
| `CheckOpen`, `CheckDone` | 72 × 72 | – | Leeres Kästchen / Kästchen mit grünem Haken (Ziele). |
| `CloseButton` | 108 × 108 | – | Runder Schließen-Knopf mit X (ohne Buchstaben, nur gekreuzte Striche). |

## C. Kleine Symbole (96 × 96, Sprite)

`IconBoost` (Blitz ×2 als zwei Blitze), `IconClubOn` (Discokugel leuchtend), `IconClubOff` (Discokugel dunkel),
`IconTrustStar`, `IconTrustStarEmpty`, `IconTimer` (Taschenuhr), `IconTripTime` (Uhr mit Rad), `IconStock`
(Kistenstapel), `IconLock` (Vorhängeschloss), `IconPause` (Kellertür zu, für „untergetaucht“), `IconPriority`
(Pfeile hoch/runter mit Kiste), `IconWarning` (Dreieck mit „!“-Symbol), `IconInfo` (Glühbirne), `IconCheck`,
`IconUpgrade` (grüner Pfeil auf Schraubenschlüssel), `IconHire` (Hand mit Hut), `IconUnlock` (Schlüssel im Schloss),
`IconCity` (drei Häuser), `IconAd` (Filmrolle, für „Video ansehen“), `IconNoAds` (durchgestrichene Filmrolle),
`IconPremium` (Krone mit ×2), `IconWarp` (Uhr mit Vorspul-Pfeilen), `IconDaily` (Briefumschlag mit Schleife),
`IconOffline` (Mond mit Münzen), `IconSound`, `IconSoundOff`, `IconMusic`, `IconMusicOff`, `IconHaptics`
(vibrierendes Telefon im 40er-Stil), `IconBell` (Benachrichtigungen), `IconLanguage` (Sprechblase mit Globus),
`IconRestore` (Pfeilkreis um eine Münze), `IconReset` (Kassenbuch mit Radiergummi).

## D. Ziele der Kapitel (192 × 192, Sprite)

Ein Bild je Zieltyp, im Stil der Auftragssymbole:
`GoalDeliver` (Roller mit Kiste), `GoalHireLead` (Hut auf Werkbank), `GoalOrders` (Stapel Briefe),
`GoalDispatcher` (Pfeife und Klemmbrett), `GoalEarn` (Münzstapel), `GoalUnlockContact` (Handschlag),
`GoalThroughput` (Fließband mit Kisten), `GoalOpenGood` (aufgebrochene Kellertür), `GoalBigOrder` (große Kiste mit
Siegel), `GoalClubNights` (Mond mit Discokugel), `GoalTrust` (Weinglas mit Stern), `GoalCityOrders` (Stadtplan mit
drei Nadeln), `GoalFinale` (Krone über dem Kassenbuch).

## E. Effekte (Sprite-Blätter)

| Name | Maß | Motiv |
|---|---|---|
| `LevelUpRibbon` | 900 × 240 | Banderole ohne Schrift mit Sternen an den Enden (für „Meilenstein“). |
| `Confetti12` | 12 Bilder à 360 × 360 | Konfetti in Gold, Grün, Rot, fällt und dreht sich. |
| `StampPaid6` | 6 Bilder à 256 × 256 | Der „Bezahlt“-Stempel (Symbol, keine Schrift) knallt aufs Papier: anheben, schlagen, Tinte spritzt. |
| `StampMissed6` | 6 Bilder à 256 × 256 | Dasselbe für „verpasst“ (rot). |
| `SpeedLines6` | 6 Bilder à 300 × 200 | Geschwindigkeitslinien hinter einem Fahrzeug (Fähigkeit „Eilfahrt“). |
| `ShiftGlow6` | 6 Bilder à 600 × 300 | Pulsierender warmer Schein mit Zahnrädern (Fähigkeit „Doppelschicht“, liegt über den Maschinen). |
| `ShushBubble4` | 4 Bilder à 180 × 180 | Sprechblase mit Finger vor Mund (Fähigkeit „Stilles Wort“). |
| `WindowSparkle6` | 6 Bilder à 180 × 180 | Funkelnder Briefumschlag öffnet sich (Fähigkeit „Neues Fenster“). |
| `MoneyRain8` | 8 Bilder à 600 × 600 | Scheine und Münzen regnen (Rückkehr nach Abwesenheit, Großauftrag). |
| `SirenGlow4` | 4 Bilder à 600 × 300 | Rot-blauer Schein für die Straße, wenn die Polizei steht. |
| `Fireflies8` | 8 Bilder à 300 × 300 | Ein paar Glühwürmchen/Funken für ruhige Nächte über der Skyline. |

## F. Menschen: Gesten

Die Werkstattleitungen und der Disponent stehen bisher nur (`Idle2`). Je eine Geste, 4 Bilder à **180 × 270**:
`BodyBrandtTalk4`, `BodyFeldTalk4`, `BodyKesslerTalk4`, `BodyWolffTalk4`, `BodyVargaTalk4` (zeigt, gestikuliert,
lacht), und `BodyVargaWhistle4` (pfeift den Wagen los). Kunden, die mit der Ware weggehen, je 8 Bilder à 132 × 210:
`BuyerCellarsCarry8`, `BuyerOldTownCarry8`, `BuyerDocksCarry8`, `BuyerNightCarry8`, `BuyerCrownCarry8`.

## G. Bilder für Fensterköpfe (Platte 1206 × 500)

`HeaderOrders` (Briefkastenwand mit Umschlägen), `HeaderCustomers` (Straßenecke mit wartenden Kunden), `HeaderCrew`
(Hinterzimmer mit Hutständer und Stühlen), `HeaderShop` (Ladentheke mit Glocke), `HeaderRewards` (Geschenkpaket auf
dem Schreibtisch), `HeaderSettings` (Schreibtisch mit Lampe, Radio, Telefon), `HeaderChallenges` (Turmuhr im Nebel),
`HeaderReturn` (Morgendämmerung über dem Lager, Geldsäcke im Wagen), `HeaderError` (aufgeschlagenes Kassenbuch mit
Tintenklecks, für Speicherfehler).

## H. Schrift

Eine **Cartoon-Schrift** für Zahlen und Überschriften, Lizenz **SIL Open Font License** (frei, kommerziell nutzbar),
mit deutschen Umlauten, ß, €, Ziffern mit fester Breite (tabular) oder einer gut lesbaren Ziffernform. Vorschlag:
„Lilita One“ für Überschriften und „Fredoka“ (Variable oder Regular/SemiBold/Bold) für Text – oder eine bessere
OFL-Wahl, dann begründen. Ablage: `App/Resources/Fonts/<Datei>.ttf` plus `App/Resources/Fonts/OFL-<Name>.txt` mit
dem Lizenztext, Eintrag in `docs/asset-credits.json` mit Quelle. **Nichts in `Info.plist` ändern**, das mache ich.

## I. Ton (gleiche Regeln wie Abschnitt 14 des ersten Auftrags)

`sfx_lift_door` (0,4–0,7 s, Gittertür rasselt), `sfx_whistle` (0,5–0,8 s, Disponent pfeift), `sfx_confetti`
(0,8–1,2 s, Papierregen und Tröte), `sfx_stamp` (0,3–0,5 s, Stempel knallt), `sfx_toggle` (0,1–0,2 s, Hebel
klackt), `sfx_ability_shift` (0,8 s, Maschinen ziehen an), `sfx_ability_rush` (0,8 s, Motor heult kurz auf),
`sfx_ability_shush` (0,6 s, „Psst“ ohne Wort, nur Zischen), `sfx_ability_window` (0,6 s, Umschlag reißt auf, Pling).

## J. Abgabe

1. **Ein Commit pro Abschnitt** (A bis I), Nachricht „assets: Teil 2 Abschnitt X – Titel“, auf den Branch pushen.
2. Vor jedem Push: Namen und Maße exakt, Alpha nur bei Sprites/Ebenen, Sprite-Blätter gleichmäßig, Run4/Lit liegen
   pixelgenau auf ihren Platten (an den Vorschau-GIFs prüfen), 9-Slice-Teile mit einfarbiger Mitte und Kantenmitte,
   keine Schrift im Bild, `scripts/shared_assets.py check` → `ASSET_PARITY_OK`, `scripts/scan_repo.py` → `SCAN_OK`.
3. Am Ende ein Abnahmeprotokoll: pro Abschnitt Stückzahl, Commit, was fehlt und warum.
