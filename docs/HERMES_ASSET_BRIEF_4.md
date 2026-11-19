# Auftrag an Hermes: alle Bilder und Klänge für NOIR LEDGER 4.0

Alles in dieser Liste gehört dazu. Es gibt keine Prioritäten: Das Spiel soll perfekt aussehen und klingen.

Repository `mrdevn4ever-sys/noir-ledger-ios`, Branch `claude/exciting-cori-5r0kcv`. Du schreibst **keinen Swift-Code**
und änderst nichts außer den hier genannten Dateien. Ich baue alles danach ein.

## 0. Regeln für jede Datei

- **Welt:** Varnholm, eine erfundene, verregnete europäische Flussstadt, 1947. Film noir: Nacht, Regen, nasse Steine,
  eine warme Lichtquelle pro Raum, starke Schatten, leichter Dunst. Gemalt-realistisch, einheitlich über alles.
- **Farben:** Grund `#0F0D0B`, Leder `#2A1D14`, Bernstein `#E0A43A`, Altgold `#C8A55A`, Messing `#D19E4A`,
  Papier `#E6D8B8`, kaltes Stadtlicht `#8FA6A0`, Rot `#E0483C` nur für Gefahr. Ware: Gras grün-gold, Crystal eisblau
  `#9FD3E0`, Pillen pflaume `#A77BC0`, Koks weiß-silbern.
- **Inhalt:** Ware wird gezeigt (Pflanzen, Kisten, Säcke, Dosen, Blöcke, Kristalle in Schalen), **nie Konsum**, keine
  Spritzen, keine Pulverlinien, kein Blut, keine Waffen im Vordergrund, keine lesbare Schrift, keine echten Marken,
  keine Gesichter realer Personen.
- **Lizenz:** nur selbst erzeugt, CC0/Public Domain oder KI-Dienste mit kommerzieller Nutzung ohne Namensnennung.
  Jede Datei bekommt einen Eintrag in `docs/asset-credits.json` (`file`, `origin`, `license`, `source_url`).
- **Bildformat:** PNG, sRGB, 8 Bit. „Platte“ = ohne Transparenz, randlos. „Sprite“ = mit Transparenz, sauber
  freigestellt, weicher Schatten erlaubt. Jedes Bild als Imageset
  `App/Resources/Assets.xcassets/<Name>.imageset/` mit PNG und `Contents.json` wie bei `RoomGlimmer0.imageset`.
- **Konsistenz:** Dieselbe Werkstatt, dasselbe Viertel, derselbe Wagen sieht in allen Stufen wie derselbe Ort bzw.
  dasselbe Fahrzeug aus: gleiche Kamera, gleicher Raum, nur die Einrichtung wächst.

## 1. Werkstätten: sichtbarer Umbau in sechs Stufen

Platte, **1536 × 480**, Seitenansicht wie eine Bühne, Boden im unteren Viertel frei für animierte Figuren.
Stufe 0 = Start, dann die Meilensteine 10, 25, 50, 100, 200.

| Name | Motiv |
|---|---|
| `BenchWeed0`–`BenchWeed5` | Leopolds Keller in der Mühlgasse. 0: eine staubige Werkbank, drei Töpfe, eine nackte Glühbirne, Spinnweben. 1: aufgeräumt, zweite Werkbank, Pflanzlampe. 2: Regalreihen mit Pflanzen, Bewässerungsschläuche. 3: Trockenleinen unter der Decke, Ventilator. 4: Kellerwand durchbrochen, zweiter Raum sichtbar. 5: ganze Halle mit Reihen, Gewächshauslicht. |
| `BenchCrystal0`–`BenchCrystal5` | Lagerhalle am Hafen. 0: ein Campingkocher, Glaskolben auf einem Brett. 1: Labortisch. 2: Kessel und Kühlschlangen. 3: Edelstahltanks. 4: Förderband mit Schalen voller blauer Kristalle. 5: industrielle Anlage, Laufstege, Dampf. |
| `BenchPills0`–`BenchPills5` | Hinterzimmer eines Clubs. 0: Handpresse auf einem Schminktisch. 1: zwei Pressen. 2: Tablettenpresse mit Trichter, Dosen. 3: Sortiermaschine, Pflaumenlicht. 4: Förderband, Verpackungsstation. 5: Fabrikraum mit Neon und Reihen glänzender Dosen. |
| `BenchCoke0`–`BenchCoke5` | Keller einer Villa in der Oberstadt. 0: Feinwaage auf einem Silbertablett. 1: Marmortisch. 2: Presse für Blöcke. 3: Tresorwand. 4: Reihen gepresster Blöcke in Papier. 5: Gewölbe mit Kristalllüster, eisblaues Licht. |

## 2. Figuren in den Werkstätten

Sprite-Blatt, **1024 × 384**, vier Einzelbilder nebeneinander à 256 × 384 (Laufen bzw. Arbeiten), Figur von der
Seite, Blick nach rechts, Silhouette mit Bernstein-Kante wie bisher `SpriteWorker`.

| Name | Motiv |
|---|---|
| `WorkerWeed` | Gärtner mit Schürze und Gießkanne. |
| `WorkerCrystal` | Laborant im Kittel mit Schutzbrille. |
| `WorkerPills` | Presser mit Ärmelschonern, trägt ein Tablett. |
| `WorkerCoke` | Mann im Anzug mit Handschuhen, trägt einen Block. |
| `WorkerCourier` | Fahrer mit Schiebermütze, trägt eine Kiste. |

## 3. Regale mit Füllstand

Sprite, **600 × 300**, Regal von vorn, fünf Füllstände (leer, ein Viertel, halb, drei Viertel, voll).

| Name | Motiv |
|---|---|
| `ShelfWeed0`–`ShelfWeed4` | Holzregal mit Kisten voller Gras. |
| `ShelfCrystal0`–`ShelfCrystal4` | Metallregal mit Fässern und Kisten. |
| `ShelfPills0`–`ShelfPills4` | Glasvitrine mit Dosen. |
| `ShelfCoke0`–`ShelfCoke4` | Tresorfächer mit Blöcken in Papier. |
| `ShelfOverflow` | Sprite 600 × 300: Kisten stapeln sich vor dem Regal, eine ist umgekippt (zeigt „Regal voll“). |
| `PropCrateWeed`, `PropCrateCrystal`, `PropCratePills`, `PropCrateCoke` | Sprite 128 × 128, je eine Kiste der Ware, leicht von oben. |
| `PropCrateEmpty` | Sprite 128 × 128, leerer Regalplatz. |

## 4. Der Wagen: sechs Fahrzeuge

Sprite, **640 × 280**, von der Seite, Fahrtrichtung rechts, nass, Scheinwerfer an, ohne Schrift. Wechselt mit den
Meilensteinen des Fuhrparks (Stufe 1, 10, 25, 50, 100, 200).

| Name | Motiv |
|---|---|
| `Fleet0` | Handkarren mit Plane, geschoben von einem Kurier. |
| `Fleet1` | Fahrrad mit Lastenanhänger. |
| `Fleet2` | Dreirad-Lieferwagen. |
| `Fleet3` | Kastenwagen der 1940er, dunkelgrün. |
| `Fleet4` | Lastwagen mit Plane. |
| `Fleet5` | Zwei Lastwagen hintereinander, Kolonne. |
| `FleetLoaded` | Sprite 640 × 280: derselbe Kastenwagen mit offener Hecktür, Kisten werden eingeladen. |

## 5. Die Viertel

Platte, **1440 × 528**, jeweils zwei Fassungen: ruhig und heiß (Aufmerksamkeit hoch: Streifenwagen mit Blaulicht,
Männer in Mänteln am Rand, mehr Licht in den Fenstern). Derselbe Ort, dieselbe Kamera.

| Name | Motiv |
|---|---|
| `QuarterCellars`, `QuarterCellarsHot` | Mühlgasse: Kellertreppe, Laterne an der Ecke, Leopolds Kellerfenster mit warmem Licht, Bäckerei mit Hintertür. |
| `QuarterOldTown`, `QuarterOldTownHot` | Altstadt: Marktplatz mit Ständen im Regen, Fachwerk, Universität mit Kuppel. |
| `QuarterDocks`, `QuarterDocksHot` | Hafen: Kräne im Nebel, Kai 7, Frachter, Stahlwerk mit Schloten. |
| `QuarterNight`, `QuarterNightHot` | Nachtviertel: Clubeingang mit Leuchtrahmen ohne Text, Schlange im Regen, Varieté-Vordach, Pflaumen-Neon. |
| `QuarterCrown`, `QuarterCrownHot` | Oberstadt: Villa am See, Limousine auf Kies, Senatorenclub mit Säulen, eisblaues Mondlicht. |
| `QuarterNightClub` | Dieselbe Platte wie `QuarterNight`, aber in der Clubnacht: Menschenmenge, Musik sichtbar durch Licht, offene Türen. |
| `CityMap` | Platte 1206 × 1600: Stadtplan von Varnholm von oben, gezeichnet wie eine alte Karte auf Papier, Fluss in der Mitte, die fünf Viertel als Flächen ohne Schrift, Leopolds Keller als kleiner roter Punkt. |

## 6. Die Abnehmer

Platte, **512 × 512**, kleine Szene pro Kontakt, wie eine Fotografie im Kassenbuch eingeklebt.

| Name | Motiv |
|---|---|
| `ContactMuehlgasse` | Straßenecke mit Laterne, ein Mann im Mantel wartet. |
| `ContactBaeckerei` | Hintertür einer Bäckerei, Mehlsäcke, warmes Licht. |
| `ContactAltmarkt` | Marktstand mit Plane, Kisten mit Gemüse, darunter eine zweite Kiste. |
| `ContactUni` | Universitätstreppe bei Nacht, Studenten mit Büchern und Schals. |
| `ContactKai7` | Hafenarbeiter am Kai, Container, Kran. |
| `ContactWerk` | Werkstor des Stahlwerks, Schichtwechsel, Funken. |
| `ContactClub` | Garderobe eines Clubs, Pflaumenlicht. |
| `ContactVariete` | Varieté-Bühne mit rotem Vorhang, Logen. |
| `ContactVilla` | Terrasse der Villa am See, Kerzenleuchter. |
| `ContactSenat` | Ledersessel im Senatorenclub, Zigarrenrauch, Kamin. |

## 7. Menschen

Porträt im Stil der vorhandenen Crew-Porträts (`shared-assets/crew/portrait-*.svg`, als PNG **384 × 384**, Kopf und
Schultern, Silhouette mit Licht von der Seite, kein reales Gesicht).

| Name | Motiv |
|---|---|
| `CrewNotary` | Der Notar: Brille, Glatze, dunkler Anzug. |
| `CrewLeopold` | Onkel Leopold als altes Foto mit Trauerrand, Hut, Schnurrbart. |

## 8. Prolog und Kapitel

| Name | Typ, Maß | Motiv |
|---|---|---|
| `ScenePrologue` | Platte 1206 × 900 | Notarbüro 1947: Schreibtisch, alter Schlüssel, Karte mit Adresse (unlesbar), ledergebundenes Kassenbuch, Regen am Fenster, Schreibtischlampe. |
| `ItemCashbox` | Sprite 384 × 384 | Leopolds Geldkassette aus Blech, offen, Geldscheine in Zeitungspapier. |
| `ItemAddressBook` | Sprite 384 × 384 | Abgegriffenes Adressbuch, eine Ecke eingeknickt. |
| `ItemTools` | Sprite 384 × 384 | Werkzeugkoffer, offen, sauber sortiert. |
| `Chapter1Intro` … `Chapter6Intro` | Platte 1206 × 700 | Je ein Bild zum Kapitelanfang: 1 Kellertür, Schlüssel im Schloss. 2 Sami Okafor im Regen vor dem Altmarkt. 3 Dario Feld am Kai im Nebel. 4 Greta Lind vor dem Clubeingang. 5 Anton Kraus in der Villa mit Handschuhen. 6 Mira Kessler über dem Stadtplan. |
| `Chapter1Outro` … `Chapter6Outro` | Platte 1206 × 700 | Je ein Bild zum Kapitelende: 1 der Keller läuft ohne den Spieler. 2 Ilse Morgen mit Rechnung. 3 Großauftrag wird verladen. 4 ausverkaufte Clubnacht. 5 Händedruck in der Oberstadt. 6 Unterschrift unter den Vertrag, Füller, Siegel. |
| `SealChapter` | Sprite 512 × 512 | Wachssiegel mit Schlüssel-Motiv, für das Abschließen eines Kapitels. |

## 9. Kassenbuch

| Name | Typ, Maß | Motiv |
|---|---|---|
| `PropLedgerPage` | Platte 1024 × 1024, nahtlos kachelbar | Vergilbte Kassenbuchseite, feine Linien, Rand, ein Tintenfleck. |
| `PropLedgerCover` | Platte 1206 × 500 | Ledereinband, aufgeschlagen, Lesebändchen. |
| `StampPaid` | Sprite 256 × 256 | Stempelabdruck „bezahlt“ als Symbol (Häkchen im Kreis), Tinte rot-braun, ohne Schrift. |
| `StampMissed` | Sprite 256 × 256 | Stempel „verpasst“ als Symbol (Kreuz im Kreis). |
| `PropInkBlot` | Sprite 128 × 128 | Frischer Tintenklecks für die Buchungsanimation. |

## 10. Aufträge, Aufmerksamkeit, Fähigkeiten, Herausforderungen

Kleine Symbole als SVG (viewBox 0 0 64 64, eine Farbe `#E0A43A`, 3-px-Linien) **und** als PNG 128 × 128.

| Name | Motiv |
|---|---|
| `OrderQuiet` | Briefumschlag, geschlossen. |
| `OrderLoud` | Briefumschlag mit Ausrufezeichen-Symbol (ohne Schrift: drei Striche). |
| `OrderBig` | Palette mit Kisten. |
| `OrderTrust` | Händedruck. |
| `OrderCity` | Stadtsilhouette. |
| `OrderFinale` | Siegel auf Papier. |
| `AttentionCalm`, `AttentionWatched`, `AttentionHot`, `AttentionUnderground` | Auge geschlossen / Auge offen / Auge mit Blaulicht / Auge durchgestrichen. |
| `AbilityDoubleShift`, `AbilityRushRun`, `AbilityNewWindow`, `AbilityQuietWord` | Zwei Zahnräder / Wagen mit Bewegungslinien / Telefon / Hand vor dem Mund. |
| `ChallengeFog`, `ChallengePressWeek`, `ChallengeStrike` | Platte 1206 × 600: Nebel über dem Hafen / Zeitungsdruckerei bei Nacht, Fotografen (ohne lesbare Schlagzeilen) / Streikposten vor dem Werkstor mit Feuertonne. |

## 11. Shop

Platte **512 × 512**, ein Bild pro Angebot, gleiche Bühne (Ledertisch, Lampe), ohne Schrift.

| Name | Motiv |
|---|---|
| `ShopStarter` | Kleines Startpaket: Lederkoffer, Bündel Geld, Gefallen-Münzen. |
| `ShopPremium` | Der stille Teilhaber: Herr im Schatten, Zigarre, Siegelring, zwei Gläser. |
| `ShopNoAds` | Zugenähter Briefschlitz an einer Tür. |
| `ShopFavorsSmall`, `ShopFavorsMedium`, `ShopFavorsLarge`, `ShopFavorsVault` | Wachsende Haufen messingfarbener Gefallen-Münzen: Handvoll, Beutel, Kassette, offener Tresor. |

## 12. App-Symbol und Start

| Name | Typ, Maß | Motiv |
|---|---|---|
| `shared-assets/brand/app-icon-master-1024.png` | Platte 1024 × 1024, **ohne Alpha** | Neues App-Symbol: aufgeschlagenes Kassenbuch mit Schlüssel darauf, Bernsteinlicht, dunkler Grund; erkennbar auch in 60 × 60. Danach `python3 scripts/shared_assets.py export` ausführen. |
| `SceneLaunch` | Platte 1206 × 2622 | Startbild: Regen auf einer Fensterscheibe, dahinter unscharf die Mühlgasse, in der Mitte Platz für das Logo. |

## 13. Ton

Ordner `App/Resources/Audio/`, AAC in `.m4a`, 44,1 kHz, Effekte mono, Musik und Atmosphären stereo, Lautheit um
−16 LUFS (Musik −20), Stille am Anfang abgeschnitten, Schleifen nahtlos.

**Effekte**

| Datei | Länge | Klang |
|---|---|---|
| `sfx_bench_weed` | 0,4–0,8 s | Gießkanne und Holzklopfen. |
| `sfx_bench_crystal` | 0,4–0,8 s | Glasklirren und Zischen. |
| `sfx_bench_pills` | 0,4–0,8 s | Mechanisches Pressen, Klack. |
| `sfx_bench_coke` | 0,4–0,8 s | Feinwaage tickt, Papier faltet. |
| `sfx_van_depart` | 1,5–2,5 s | Fahrzeug startet und fährt im Regen weg. |
| `sfx_van_arrive` | 1–2 s | Fahrzeug hält, Tür klappt. |
| `sfx_ink` | 0,3–0,6 s | Füller kratzt eine Zeile ins Kassenbuch (jede Buchung). |
| `sfx_order_paid` | 0,8–1,2 s | Gedämpfte Kassenglocke, Münzen. |
| `sfx_order_failed` | 0,6–1 s | Stempel knallt, Papier wird zerknüllt. |
| `sfx_offer_new` | 0,5–1 s | Brief rutscht durch einen Schlitz. |
| `sfx_shelf_full` | 0,5–0,9 s | Kiste stößt gegen volles Regal. |
| `sfx_upgrade` | 0,5–0,9 s | Werkzeug, Schraube festgezogen. |
| `sfx_rebuild` | 1,5–2,5 s | Umbau bei einem Meilenstein: Hämmern, Sägen, ein Ruck, Abschluss mit Glocke. |
| `sfx_hire` | 0,8–1,2 s | Handschlag, Stuhl rückt, Mantel wird aufgehängt. |
| `sfx_chapter` | 2–3 s | Siegel wird ins Wachs gedrückt, tiefe Glocke. |
| `sfx_attention_up` | 0,6–1 s | Ferne Polizeipfeife, gedämpft. |
| `sfx_attention_down` | 0,6–1 s | Ausatmen, Regen wird leiser. |
| `sfx_club_start` | 1–2 s | Tür öffnet sich, Swingmusik bricht herein. |
| `sfx_challenge_start` | 1–2 s | Nebelhorn (Nebel) bzw. allgemein: Turmuhr schlägt. |
| `sfx_challenge_won` | 1,5–2,5 s | Kleine Blechbläser-Fanfare, gedämpft. |
| `sfx_ui_tap` | 0,05–0,15 s | Leiser Papierklick für Knöpfe. |
| `sfx_ui_sheet` | 0,2–0,4 s | Seite wird umgeblättert (Fenster öffnet sich). |

**Atmosphären** (30–60 s, nahtlos)

`amb_cellars` (Regen, Tropfen, Straßenbahn fern), `amb_oldtown` (Regen auf Markisen, Schritte, Glocke fern),
`amb_docks` (Wellen, Möwen, Nebelhorn fern, Kran), `amb_night` (gedämpfte Clubmusik durch Wände, Stimmen),
`amb_crown` (Regen auf Kies, Grillen, Klavier fern).

**Musik** (90–120 s, nahtlos, Jazz/Noir, Kontrabass, Besen, gedämpfte Trompete, Klavier)

`music_cellars`, `music_oldtown`, `music_docks`, `music_night`, `music_crown`, `music_finale` (feierlicher, Streicher),
`music_prologue` (ruhig, nur Klavier und Regen).

## 14. Abgabe

1. Ein Commit pro Abschnitt (1 bis 13), auf den Branch pushen.
2. `docs/asset-credits.json` für jede Datei ergänzen.
3. Am Ende eine kurze Liste schicken: was geliefert ist, was nicht und warum.
