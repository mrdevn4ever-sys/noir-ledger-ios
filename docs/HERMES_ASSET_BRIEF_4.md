# Auftrag an Hermes: alle Grafiken, Animationen, Klänge und Musik für NOIR LEDGER 4.0 (Cartoon bei Nacht)

**Alles in diesem Dokument hat Priorität 1. Nichts auslassen, nichts vereinfachen, nichts ersetzen.** Wenn etwas
nicht machbar ist, schreib in der Abschlussliste genau, was und warum.

Repository `mrdevn4ever-sys/noir-ledger-ios`, Branch `claude/exciting-cori-5r0kcv`. Du schreibst **keinen Swift-Code**
und änderst nichts außer den hier genannten Dateien. Ich baue alles ein. Der Code sucht jede Datei **nach ihrem
Namen**: Name, Maß und Format müssen exakt stimmen.

---

## 0. Das Spiel und der Stil

NOIR LEDGER ist ein Idle-Tycoon für iPhone im Hochformat. Der Bildschirm ist ein **Querschnitt durch ein Gebäude bei
Nacht**: oben die Straße mit unserem Lager, einem Roller/Lieferwagen und dem Haus der Kunden; links ein
Aufzugsschacht; darunter eine Etage pro Ware (Gras, Crystal, Pillen, Koks) mit Arbeitern, Maschinen und einem
Kistenstapel; unten das Fundament. Die Stadt heißt Varnholm, eine erfundene Flussstadt im Europa der späten 1940er.
Ton: schwarzer Humor, Satire, freche Figuren, nie verherrlichend.

**Stil (für jede Datei verbindlich):**

- Flacher 2D-Cartoon mit klaren Formen, **dunkle Kontur** `#1B1B28`, Konturstärke 3 px bei @3x (1 pt).
- **Zellschattierung**: eine Grundfarbe plus ein Schattenton, ein Glanzlicht. Keine Verläufe auf Figuren, nur auf
  Himmel und Lichtkegeln.
- **Nacht**: kühles Blau als Umgebung, warmes Gelb aus Lampen und Fenstern als Akzent. Jede Etage hat ihre eigene
  Lichtfarbe (siehe Waren).
- **Figuren**: große Köpfe (etwa ein Drittel der Körperhöhe), große Augen, ausdrucksstarke Gesichter, schlanke Körper,
  1940er-Kleidung (Hüte, Hosenträger, Mäntel, Schiebermützen). Freundlich-gerissen, nie brutal.
- **Eigenständig**: Lass dich nicht zum Kopieren verleiten. Keine Figur, kein Gebäude, kein Symbol darf wie aus einem
  bestehenden Spiel aussehen (z. B. Idle Miner Tycoon, Weed Inc.). Eigene Formen, eigene Gesichter, eigene Farben.

**Farben (Hex, einhalten):**

| Rolle | Farbe |
|---|---|
| Himmel oben / unten | `#1B2450` / `#3A4C8A` |
| Skyline fern / nah | `#2D3B70` / `#24305E` |
| Fensterlicht, Gold, Geld | `#FFD66B`, `#FFC83D`, `#F2B544` |
| Grund der App, Panels | `#141A33`, `#1E2648`, `#283259` |
| Ziegelwand Etage | `#262B40` mit Fugen `#1C2033` |
| Boden Etage | `#4A4F68`, Kante `#2E3247` |
| Straße / Bordstein | `#3B3F55` / `#5A5F7A` |
| Dach, Level-Abzeichen | `#C8463C`, `#D9433B`, dunkel `#A8302A` |
| Grün für „aufwerten“ | `#3FC45A` |
| Gefahr (nur Polizei, voll, verpasst) | `#E5484D` |
| Kisten | `#E39A4C`, dunkel `#B86F2E` |
| Gras | Blätter `#4FBF4A` / `#2F8F35`, Blüten `#C6E85A` |
| Crystal | `#5FC9F0`, Glas `#BFE8F2` |
| Pillen | `#B07CE0`, `#F07CB0` |
| Koks | `#F3F3F3`, Marmor `#D9DCE6`, Silber `#9AA2B8` |
| Papier (Kassenbuch) | `#F3E9D2`, Tinte `#2B2440` |

**Inhalt:** Ware wird gezeigt (Pflanzen, Kristalle, Tabletten, gepresste Blöcke, Kisten, Säcke, Dosen). **Nie
Konsum**: keine Spritzen, keine Pulverlinien, kein Rauchen von Drogen, keine berauschten Figuren. Keine Waffen, kein
Blut. **Keine lesbare Schrift** in Bildern (Schilder als Symbole oder Leuchtrahmen), keine echten Marken oder Logos,
keine echten Personen.

**Lizenz:** nur selbst erzeugt, CC0/Public Domain oder KI-Dienste, deren Bedingungen kommerzielle Nutzung ohne
Namensnennung erlauben. Jede Datei bekommt einen Eintrag in `docs/asset-credits.json`:
`{ "file": "...", "origin": "...", "license": "...", "source_url": "..." }`.

## 0.1 Technische Regeln

- **Maße in Pixeln bei @3x** (iPhone). Alles als **PNG, sRGB, 8 Bit pro Kanal**.
- „Platte“ = ohne Transparenz, randlos bis an die Kante. „Sprite“ = mit Alpha, sauber freigestellt, 2 px Luft rundum,
  weiche Schatten erlaubt.
- Jedes Bild als Imageset: `App/Resources/Assets.xcassets/<Name>.imageset/<name>.png` plus `Contents.json`:
  ```json
  { "images": [ { "filename": "<name>.png", "idiom": "universal" } ], "info": { "author": "xcode", "version": 1 } }
  ```
- **Sprite-Blätter** (Animationen): alle Einzelbilder gleich groß, **waagerecht** nebeneinander, Reihenfolge von links
  nach rechts, Figur in jedem Bild an derselben Stelle (Füße auf derselben Linie, mittig). Der Name endet auf die
  Bildzahl, z. B. `WorkerWeedWalk8` = 8 Bilder.
- **Ankerpunkt**: Figuren und Fahrzeuge stehen mit den Füßen bzw. Rädern auf der Unterkante des Bildes (4 px Luft).
- **Blickrichtung**: alles schaut nach **rechts**. Ich spiegele im Code.
- **Konsistenz**: dieselbe Figur sieht in allen Animationen gleich aus; dieselbe Etage in allen Ausbaustufen ist
  derselbe Raum aus derselben Kamera; dasselbe Fahrzeug in allen Bildern gleich groß.
- Ton: siehe Abschnitt 14.

---

## 1. Himmel und Stadt (Ebenen für Parallaxe)

| Name | Typ | Maß | Motiv |
|---|---|---|---|
| `SkyNight` | Platte | 1206 × 810 | Nachthimmel mit Verlauf `#1B2450` → `#3A4C8A`, kleine Sterne, ein paar flache Wolken. Kein Mond. |
| `Moon` | Sprite | 150 × 150 | Voller Mond mit weichem Schein, Cartoon-Krater. |
| `SkylineFar` | Sprite | 1206 × 300 | Ferne Silhouetten: Kirchturm, Kuppel, Kräne, Fabrikschlote, wenige gelbe Fenster. Unterkante gerade, kachelbar nach links/rechts. |
| `SkylineNear` | Sprite | 1206 × 360 | Nähere Häuserreihe der Altstadt, Dachgauben, Schornsteine, viele erleuchtete Fenster. Kachelbar. |
| `Street` | Platte | 1206 × 140 | Kopfsteinpflaster-Straße mit Bordstein, Gully, zwei Pfützen mit Spiegelung. Kachelbar waagerecht. |
| `StreetLamp` | Sprite | 140 × 260 | Gusseiserne Laterne, Licht an. |
| `StreetLampGlow` | Sprite | 300 × 300 | Nur der Lichtschein der Laterne (weicher gelber Kreis), für Überblendung. |
| `RainSheet4` | Sprite | 2048 × 512 | 4 Bilder à 512 × 512, Regenstriche, nahtlos kachelbar, für eine Regen-Ebene. |
| `Puddle` | Sprite | 180 × 40 | Pfütze mit Lichtspiegelung. |

## 2. Unser Lager an der Straße (drei Ausbaustufen des Wagens)

Sprite, **384 × 450**. Links eine offene Aufzugsöffnung **genau 162 px breit**, die sich nach unten in den Schacht
fortsetzt (transparent in der Öffnung). Rechts eine Tür. Platz für ein Abzeichen in der Mitte.

| Name | Motiv |
|---|---|
| `Depot0` | Schäbiger Kellereingang mit Holzverschlag, eine Glühbirne. |
| `Depot1` | Renoviertes Ladenlokal mit Rolltor, Markise. |
| `Depot2` | Kleines Lagerhaus mit Laderampe, Leuchtkasten ohne Schrift. |
| `LiftHead` | Sprite 162 × 120: Aufzugskopf mit Rad und Seil, Rost, Bolzen. |
| `Mailbox` | Sprite 120 × 120: Briefkasten an der Wand, Klappe offen, ein Brief steckt heraus (Symbol für neue Aufträge). |
| `MailboxClosed` | Sprite 120 × 120: derselbe Briefkasten, zu. |

## 3. Das Haus der Kunden (eines pro Viertel)

Sprite, **354 × 450**, Eingang links unten, wo der Roller hält. Jeweils zwei Fassungen: normal und „heiß“ (Fenster
dunkel, Vorhänge zu, ein Polizeiaufkleber-Symbol an der Tür ohne Schrift).

| Name | Motiv |
|---|---|
| `CustomersCellars`, `CustomersCellarsHot` | Eckladen in der Mühlgasse mit Bäckerei-Hintertür, Mehlsäcke. |
| `CustomersOldTown`, `CustomersOldTownHot` | Markthalle der Altstadt mit Ständen unter einem Bogen. |
| `CustomersDocks`, `CustomersDocksHot` | Hafenschuppen mit Kran-Haken und Containern. |
| `CustomersNight`, `CustomersNightHot` | Clubeingang mit Leuchtrahmen, Samtkordel, Türsteher-Platz. |
| `CustomersCrown`, `CustomersCrownHot` | Villeneingang mit Säulen, Laternen, Kies. |

## 4. Aufzug

| Name | Typ | Maß | Motiv |
|---|---|---|---|
| `ShaftTile` | Platte | 162 × 588 | Schachtstück, senkrecht nahtlos kachelbar: dunkle Wand, zwei Führungsschienen, Bolzen. |
| `LiftCarEmpty` | Sprite | 138 × 168 | Aufzugskabine mit Gittertür, Lampe, leer, ein Kurier steht darin. |
| `LiftCarLoaded` | Sprite | 138 × 168 | Dieselbe Kabine voller Kisten. |
| `LiftCable` | Sprite | 12 × 588 | Seilstück, senkrecht kachelbar. |
| `LiftDoorOpen6` | Sprite | 828 × 168 | 6 Bilder à 138 × 168: die Gittertür geht auf. |

## 5. Etagen in sechs Ausbaustufen

Platte, **1206 × 588**. Links ein **162 px** breiter Streifen für den Schacht (dunkel lassen, wird überdeckt).
Unten **54 px** Boden. Die Maschinen stehen im rechten Teil zwischen x = 450 und x = 950, der Bereich x = 162 bis
x = 450 bleibt frei für den Kistenstapel und den Manager. Rechts ab x = 990 Platz für das Level-Abzeichen.
Stufe 0 = Start, dann die Meilensteine 10, 25, 50, 100, 200. **Derselbe Raum in allen sechs Stufen.**

| Name | Motiv |
|---|---|
| `FloorWeed0`–`FloorWeed5` | Leopolds Keller. 0: drei Töpfe mit kleinen Pflanzen, nackte Glühbirne, Spinnweben. 1: fünf Töpfe, eine Pflanzlampe. 2: zwei Reihen Töpfe, Bewässerungsschlauch. 3: hohe Pflanzen mit Blüten, Trockenleine unter der Decke. 4: Hochbeete, Ventilator, zwei Lampenreihen. 5: dichter Dschungel mit Blüten, Gewächshauslicht, kleine Drohne. |
| `FloorCrystal0`–`FloorCrystal5` | Labor am Hafen. 0: Campingkocher und zwei Kolben auf einem Brett. 1: Labortisch mit Brennern. 2: Destille mit Kühlschlangen. 3: Edelstahlkessel. 4: Förderband mit Schalen blauer Kristalle. 5: ganze Anlage mit Laufsteg und Dampf. |
| `FloorPills0`–`FloorPills5` | Hinterzimmer eines Clubs. 0: Handpresse auf einem Schminktisch. 1: zwei Pressen. 2: Tablettenpresse mit Trichter. 3: Sortiermaschine, Discokugel. 4: Förderband und Abfüllstation. 5: Fabrik mit Neon und Reihen glänzender Dosen. |
| `FloorCoke0`–`FloorCoke5` | Weinkeller einer Villa. 0: Feinwaage auf einem Silbertablett. 1: Marmortisch. 2: Presse für Blöcke. 3: Tresorwand. 4: Regale mit Blöcken in Papier. 5: Gewölbe mit Kronleuchter. |
| `FloorWeedLocked`, `FloorCrystalLocked`, `FloorPillsLocked`, `FloorCokeLocked` | Platte 1206 × 396: dieselbe Etage zugemauert, Bretter vor der Tür, Spinnweben, ein Schloss. |
| `Foundation` | Platte 1206 × 210: Erde mit Steinen, Wurzeln, einer verbuddelten Kiste. |
| `FloorLampOn`, `FloorLampOff` | Sprite 90 × 216: Hängelampe mit bzw. ohne Lichtkegel (pro Etage viermal verwendet). |

**Animierte Teile auf den Etagen** (Sprites, ergänzen die Platten):

| Name | Maß | Motiv |
|---|---|---|
| `PlantWeedSway8` | 8 Bilder à 120 × 210 | Eine Hanfpflanze im Topf, die sich leicht wiegt. |
| `FlaskBubble8` | 8 Bilder à 90 × 120 | Kolben mit blubbernder blauer Flüssigkeit. |
| `PressStamp6` | 6 Bilder à 180 × 240 | Pillenpresse, der Stempel geht runter und hoch, Tabletten fallen heraus. |
| `ScaleTip6` | 6 Bilder à 150 × 120 | Feinwaage, die ausschlägt. |
| `ConveyorPills8` | 8 Bilder à 330 × 60 | Förderband mit Tabletten, nahtlos laufend. |
| `SteamPuff6` | 6 Bilder à 120 × 120 | Dampfwolke. |
| `DustPuff6` | 6 Bilder à 180 × 180 | Staubwolke für den Umbau bei einem Meilenstein. |

## 6. Figuren (Sprite-Blätter)

Jedes Einzelbild **132 × 210**. Pro Rolle: `Walk8` (8 Bilder laufen), `Carry8` (8 Bilder laufen mit Kiste vor der
Brust), `Work4` (4 Bilder arbeiten an der Station), `Idle2` (2 Bilder stehen, atmen, blinzeln), `Sleep2` (2 Bilder
dösen im Stehen mit „Zzz“, für Stationen ohne Personal).

| Präfix | Rolle und Aussehen |
|---|---|
| `WorkerWeed` | Gärtner: Latzhose, Strohhut, Gießkanne, Gartenhandschuhe. |
| `WorkerCrystal` | Laborant: Kittel, Schutzbrille auf der Stirn, Gummihandschuhe. |
| `WorkerPills` | Presser: Hosenträger, Ärmelschoner, Schiebermütze, Schürze. |
| `WorkerCoke` | Anzugträger: Nadelstreifen, Handschuhe, kleiner Schnurrbart. |
| `WorkerCourier` | Kurier/Aufzugsführer: Arbeitsjacke, Mütze, Kiste. |

**Kunden und Straße** (gleiche Bildgröße, `Idle2` und `Walk8`):

| Präfix | Aussehen |
|---|---|
| `BuyerCellars` | Typ an der Ecke: Kapuze, Hände in den Taschen. |
| `BuyerOldTown` | Student mit Schal, Brille, Bücher unterm Arm. |
| `BuyerDocks` | Hafenarbeiter mit Strickmütze, Seesack. |
| `BuyerNight` | Clubgängerin im Glitzerkleid mit Federboa. |
| `BuyerCrown` | Gast im Frack mit Zylinder und Monokel. |
| `Cop` | Polizist in langem Mantel mit Schirmmütze (zusätzlich `Notebook4`: schreibt in ein Notizbuch). |

## 7. Menschen der Geschichte (Porträts und Ganzkörper)

Die vorhandenen Porträts sind im alten Noir-Stil und werden **alle ersetzt**. Für jede Person:

- **Porträt**: Sprite **384 × 384**, Kopf und Schultern, leicht nach rechts gedreht, runder Ausschnitt mit Rand möglich,
  Name: `Crew<Name>` (ersetzt das bestehende Imageset gleichen Namens, z. B. `CrewBrandt`).
- **Ganzkörper**: Sprite **180 × 270**, stehend, `Idle2` als Blatt 360 × 270, Name: `Body<Name>Idle2`.
- **Ausdrücke**: drei zusätzliche Porträts `Crew<Name>Happy`, `Crew<Name>Angry`, `Crew<Name>Smug` für die
  Kapitelgeschichten.

| Name | Person | Aussehen |
|---|---|---|
| `Brandt` | Jonas Brandt, Werkstattleitung Gras | Mitte 50, Strohhut, Bart, Erde an den Händen, gutmütig. |
| `Varga` | Emil Varga, Disponent | 30, Schiebermütze, Zahnstocher, flink, Lederjacke. |
| `Okafor` | Sami Okafor, Kontaktperson | 30, Frau, Turban-Tuch, Notizbuch, wissendes Lächeln. |
| `Morgen` | Ilse Morgen, Buchhalterin | 60, Frau, Dutt, Lesebrille an Kette, Ärmelschoner. |
| `Feld` | Dario Feld, Werkstattleitung Crystal / Hafenmeister | 40, Kapitänsmütze, Seemannspullover, Narbe am Kinn. |
| `Wolff` | Hanna Wolff, Werkstattleitung Koks | 45, Frau, Hochsteckfrisur, Perlenkette, kühler Blick. |
| `Kessler` | Mira Kessler, Werkstattleitung Pillen / Stadtplanerin | 35, Frau, Kurzhaar, Overall, Werkzeuggürtel. |
| `Hollis` | Lena Hollis, Kurierin | 25, Frau, Fliegerbrille auf der Mütze, Halstuch. |
| `Sand` | Viktor Sand, Hafenschutz | 40, groß, Glatze, Hafenarbeiter-Weste, verschränkte Arme. |
| `Reiter` | Paul Reiter, Buchhalter (Reserve) | 50, Fliege, Ärmelschoner, Rechenschieber. |
| `Kraus` | Anton Kraus, Anwalt | 55, Nadelstreifen, Melone, Lederhandschuhe, Aktentasche. |
| `Lind` | Greta Lind, Clubpromoterin | 30, Frau, Bob-Frisur, Federboa, Zigarettenspitze (ohne Rauch). |
| `Notary` | Der Notar | 65, Glatze, kleine runde Brille, Weste, Stempel in der Hand. |
| `Leopold` | Onkel Leopold (verstorben) | als altes Foto mit Trauerrand: Hut, Schnurrbart, verschmitzt. Nur Porträt, kein Ganzkörper. |

## 8. Fahrzeuge (sechs Ausbaustufen des Wagens) und Polizei

Jedes Fahrzeug als **Karosserie ohne Räder** plus **ein Rad** (das Rad drehe ich im Code). Fahrer sitzt in der
Karosserie. Fahrtrichtung rechts.

| Name | Maß | Motiv |
|---|---|---|
| `Fleet0Body`, `Fleet0Wheel` | 300 × 200, 54 × 54 | Handkarren mit Plane, geschoben vom Kurier (Kurier als Teil des Bildes, Beine in `Fleet0Push8`, 8 Bilder à 300 × 200). |
| `Fleet1Body`, `Fleet1Wheel` | 300 × 200, 66 × 66 | Fahrrad mit Lastenanhänger. |
| `Fleet2Body`, `Fleet2Wheel` | 300 × 200, 60 × 60 | Motorroller mit Kiste hinten. |
| `Fleet3Body`, `Fleet3Wheel` | 360 × 220, 66 × 66 | Dreirad-Lieferwagen. |
| `Fleet4Body`, `Fleet4Wheel` | 420 × 240, 78 × 78 | Kastenwagen der 1940er, dunkelgrün, Scheinwerfer an. |
| `Fleet5Body`, `Fleet5Wheel` | 540 × 260, 84 × 84 | Lastwagen mit Plane. |
| `Exhaust6` | 6 Bilder à 90 × 90 | Auspuffwölkchen. |
| `PoliceCarBody`, `PoliceCarWheel` | 420 × 240, 78 × 78 | Streifenwagen der 1940er, Blau-Weiß, ohne Schrift. |
| `PoliceSiren2` | 2 Bilder à 120 × 60 | Blaulicht an/aus mit Schein. |

## 9. Kisten, Geld, Effekte

| Name | Typ | Maß | Motiv |
|---|---|---|---|
| `CrateWeed`, `CrateCrystal`, `CratePills`, `CrateCoke` | Sprite | 78 × 62 | Kiste je Ware mit Symbol der Ware auf der Seite (Blatt, Kristall, Tablette, Block). |
| `CrateSlot` | Sprite | 78 × 62 | Leerer Platz auf dem Regalbrett. |
| `ShelfFrame` | Sprite | 180 × 216 | Holzregal mit drei Brettern, in das die Kisten gestapelt werden. |
| `ShelfFullSign` | Sprite | 150 × 60 | Rotes Schild ohne Schrift mit Ausrufezeichen-Symbol, schief angenagelt. |
| `Coin` | Sprite | 48 × 48 | Goldmünze mit Schlüssel-Prägung (kein Dollar- oder Euro-Zeichen). |
| `CoinSpin6` | Sprite | 288 × 48 | 6 Bilder à 48 × 48, Münze dreht sich. |
| `CashBundle` | Sprite | 96 × 60 | Geldbündel mit Banderole, ohne Schrift. |
| `CoinBurst8` | Sprite | 1536 × 192 | 8 Bilder à 192 × 192, Münzen spritzen heraus (Auftrag bezahlt). |
| `StarBurst8` | Sprite | 1536 × 192 | 8 Bilder, goldene Sterne (Stufe gekauft). |
| `RebuildBurst8` | Sprite | 2880 × 360 | 8 Bilder à 360 × 360, Hämmer, Sterne, Staub (Meilenstein-Umbau). |
| `Favor` | Sprite | 96 × 96 | Die Premiumwährung „Gefallen“: violettes Wachssiegel mit Handschlag-Prägung. |
| `FavorPile` | Sprite | 192 × 140 | Kleiner Haufen Gefallen-Siegel. |

## 10. Bedienelemente im Spiel

| Name | Typ | Maß | Motiv |
|---|---|---|---|
| `BadgePlate` | Sprite | 186 × 150 | Rote Plakette mit dunklerem unterem Rand (Hintergrund für „Level N“), leerer Text-Bereich. |
| `BadgePlateGrey` | Sprite | 186 × 150 | Dieselbe in Grau (gesperrt). |
| `ArrowUp` | Sprite | 60 × 60 | Grüner Pfeil nach oben (aufwerten möglich). |
| `ArrowUpPulse4` | Sprite | 240 × 60 | 4 Bilder, Pfeil hüpft. |
| `BottleneckBubble` | Sprite | 72 × 72 | Rote Sprechblase mit Ausrufezeichen-Symbol. |
| `ManagerSlot` | Sprite | 90 × 138 | Gestrichelte Figur-Silhouette mit Plus. |
| `TapHand4` | Sprite | 480 × 120 | 4 Bilder à 120 × 120, Zeigehand tippt (für das Tutorial). |
| `HudCoin` | Sprite | 96 × 96 | Große Münze für die Geldanzeige. |
| `HudFavor` | Sprite | 72 × 72 | Gefallen-Siegel klein. |
| `IconBook`, `IconGift`, `IconGiftOpen`, `IconSettings` | Sprite | 96 × 96 | Kopfleisten-Symbole im Cartoon-Stil. |
| `NavOrders`, `NavCustomers`, `NavCrew`, `NavCity`, `NavBook` | Sprite | 90 × 90 | Symbole der unteren Leiste: Brief, zwei Kunden, drei Arbeiter, Stadtplan, Kassenbuch. |
| `ChapterRibbon` | Sprite | 1080 × 150 | Pergamentband für Kapitel und Ziele, links Platz für ein rundes Porträt. |
| `HintBubble` | Sprite | 1080 × 180 | Gelbe Sprechblase mit Spitze nach unten (Tutorial). |

## 11. Aufträge, Aufmerksamkeit, Fähigkeiten, Herausforderungen

Symbole als **SVG** (viewBox 0 0 64 64) **und** als PNG-Sprite 192 × 192, im Cartoon-Stil mit Kontur.

| Name | Motiv |
|---|---|
| `OrderQuiet` | Geschlossener Briefumschlag mit Wachssiegel. |
| `OrderLoud` | Briefumschlag, der zappelt, mit Ausrufezeichen-Symbol (ohne Schrift). |
| `OrderBig` | Palette voller Kisten. |
| `OrderTrust` | Händedruck mit Glitzer. |
| `OrderCity` | Kleine Stadtsilhouette mit Paket. |
| `OrderFinale` | Vertrag mit Füller und Siegel. |
| `AttentionCalm`, `AttentionWatched`, `AttentionHot`, `AttentionUnderground` | Schlafendes Auge / offenes Auge / Auge mit Blaulicht / Auge hinter einem Gullydeckel. |
| `AbilityDoubleShift`, `AbilityRushRun`, `AbilityNewWindow`, `AbilityQuietWord` | Zwei Zahnräder mit Blitz / Roller mit Geschwindigkeitsstreifen / klingelndes Telefon / Finger vor dem Mund. |
| `SpecialistOkafor`, `SpecialistMorgen`, `SpecialistSand`, `SpecialistLind`, `SpecialistKraus` | Kleine Wappen für die Spezialisten: Notizbuch / Rechenschieber / Anker / Federboa / Aktentasche. |
| `ChallengeFog`, `ChallengePressWeek`, `ChallengeStrike` | Platte **1206 × 600**: der Hafen im dicken Nebel / Fotografen und Zeitungsjungen vor der Druckerei (Zeitungen ohne Schrift) / Streikposten mit Feuertonne vor dem Werkstor. |
| `ChallengeFogIcon`, `ChallengePressWeekIcon`, `ChallengeStrikeIcon` | Sprite 192 × 192 zu den drei Herausforderungen. |

## 12. Geschichte: Prolog, Startwahl, Kapitel, Stadtplan

| Name | Typ | Maß | Motiv |
|---|---|---|---|
| `ScenePrologue` | Platte | 1206 × 900 | Notarbüro: der Notar schiebt einen Schlüssel und ein Kassenbuch über den Tisch, Regen am Fenster, Leopolds Foto an der Wand. |
| `ItemCashbox`, `ItemAddressBook`, `ItemTools` | Sprite | 384 × 384 | Die drei Startgegenstände: offene Blechkassette mit Geldbündeln / abgegriffenes Adressbuch mit eingeknickter Seite / Werkzeugkoffer, sauber sortiert. |
| `Chapter1Intro` … `Chapter6Intro` | Platte | 1206 × 700 | 1: Spieler schließt die Kellertür auf, Staub. 2: Sami Okafor vor dem Altmarkt im Regen. 3: Dario Feld am nebligen Kai. 4: Greta Lind vor dem Club. 5: Anton Kraus in der Villa. 6: Mira Kessler über dem Stadtplan. |
| `Chapter1Outro` … `Chapter6Outro` | Platte | 1206 × 700 | 1: Keller läuft, Brandt gießt, Varga winkt. 2: Ilse Morgen mit Rechnung und Brille. 3: Großauftrag wird auf einen Frachter verladen. 4: ausverkaufte Clubnacht. 5: Händedruck mit dem Senator. 6: Unterschrift, Siegel, Feuerwerk über Varnholm. |
| `SealChapter` | Sprite | 512 × 512 | Wachssiegel mit Schlüssel, zum Abschließen eines Kapitels. |
| `CityMap` | Platte | 1206 × 1600 | Stadtplan von Varnholm von oben im Cartoon-Stil: Fluss in der Mitte, Brücken, die fünf Viertel als erkennbare Inseln (Mühlgasse, Altstadt, Hafen, Nachtviertel, Oberstadt), keine Schrift. |
| `CityMapPin` | Sprite | 120 × 150 | Stecknadel mit Kopf in Bernstein. |
| `QuarterCellars`, `QuarterOldTown`, `QuarterDocks`, `QuarterNight`, `QuarterCrown` | Sprite | 240 × 240 | Rundes Symbolbild je Viertel für Listen. |
| `QuarterCellarsWide` … `QuarterCrownWide` (5) | Platte | 1206 × 420 | Breites Stimmungsbild je Viertel für die Stadt-Ansicht. |
| `ContactMuehlgasse`, `ContactBaeckerei`, `ContactAltmarkt`, `ContactUni`, `ContactKai7`, `ContactWerk`, `ContactClub`, `ContactVariete`, `ContactVilla`, `ContactSenat` | Sprite | 384 × 384 | Ein Bild pro Abnehmer: Straßenecke / Bäckerei-Hintertür / Marktstand / Hörsaaltreppe / Hafenarbeiter am Kai / Werkstor / Club-Garderobe / Varieté-Bühne / Villen-Terrasse / Ledersessel im Senatorenclub. |

## 13. Kassenbuch, Shop, App-Symbol, Startbild, App Store

| Name | Typ | Maß | Motiv |
|---|---|---|---|
| `LedgerPage` | Platte | 1024 × 1024 | Kassenbuchseite, nahtlos kachelbar, Linien, Rand, Tintenfleck. |
| `LedgerCover` | Platte | 1206 × 500 | Aufgeschlagenes Kassenbuch auf dem Schreibtisch, Lesebändchen, Füller. |
| `StampPaid`, `StampMissed` | Sprite | 256 × 256 | Stempelabdruck Häkchen im Kreis / Kreuz im Kreis, Tinte rot-braun, ohne Schrift. |
| `InkBlot` | Sprite | 128 × 128 | Frischer Tintenklecks. |
| `ShopStarter` | Sprite | 512 × 512 | Lederkoffer mit Geldbündeln und Gefallen-Siegeln. |
| `ShopPremium` | Sprite | 512 × 512 | Der stille Teilhaber: Mann im Schatten mit Zigarre (nicht angezündet), Siegelring, zwei Gläser. |
| `ShopNoAds` | Sprite | 512 × 512 | Zugenagelter Briefschlitz, durchgestrichener Flyer. |
| `ShopFavorsSmall`, `ShopFavorsMedium`, `ShopFavorsLarge`, `ShopFavorsVault` | Sprite | 512 × 512 | Handvoll / Beutel / Kassette / offener Tresor voller Gefallen-Siegel. |
| `ShopBoost` | Sprite | 512 × 512 | Sanduhr mit Blitz (Doppelte Einnahmen). |
| `ShopWarp` | Sprite | 512 × 512 | Taschenuhr, deren Zeiger rasen (Zeitsprung). |
| `ShopCalm` | Sprite | 512 × 512 | Umschlag wird einem Polizisten zugesteckt (Aufmerksamkeit senken). |
| `shared-assets/brand/app-icon-master-1024.png` | Platte | 1024 × 1024, **ohne Alpha** | Neues App-Symbol: Querschnitt unseres Gebäudes bei Nacht in klein (Straße, Aufzug, eine leuchtende Etage mit Pflanzen) oder ein aufgeschlagenes Kassenbuch mit Schlüssel; muss in 60 × 60 erkennbar sein. Danach `python3 scripts/shared_assets.py export` ausführen. |
| `SceneLaunch` | Platte | 1206 × 2622 | Startbild: das Gebäude bei Nacht von außen, Regen, in der Mitte Platz für das Logo. |
| `Wordmark` | Sprite | 1200 × 360 | Schriftzug „NOIR LEDGER“ im Cartoon-Stil (die einzige erlaubte Schrift, ersetzt `BrandWordmark`). |
| `AppStoreBg1` … `AppStoreBg6` | Platte | 1290 × 2796 | Hintergründe für die App-Store-Bilder, oben 600 px Platz für eine Überschrift, sonst Stimmung: Gebäude, Etagen, Straße, Stadtplan, Crew, Kassenbuch. |

## 14. Ton und Musik

Ordner `App/Resources/Audio/`. AAC in `.m4a`, 44,1 kHz. Effekte **mono**, Atmosphären und Musik **stereo**.
Lautheit: Effekte um −16 LUFS, Atmosphären −24 LUFS, Musik −20 LUFS. Stille am Anfang abschneiden, Schleifen
**nahtlos**. Klangfarbe: verspielt, Cartoon-tauglich, aber mit 1940er-Charme (Holz, Messing, Glocken, Swing).

**Effekte (alle):**

| Datei | Länge | Klang |
|---|---|---|
| `sfx_bench_weed` | 0,3–0,6 s | Gießkanne plätschert, kurzes Holzklopfen. |
| `sfx_bench_crystal` | 0,3–0,6 s | Glasklirren, Blubbern. |
| `sfx_bench_pills` | 0,3–0,6 s | Mechanisches Pressen, Klack. |
| `sfx_bench_coke` | 0,3–0,6 s | Feinwaage tickt, Papier knistert. |
| `sfx_crate_drop` | 0,2–0,4 s | Kiste landet auf dem Stapel. |
| `sfx_lift_move` | 1–1,5 s, schleifbar | Aufzug surrt, Seil knarrt. |
| `sfx_lift_ding` | 0,4–0,7 s | Aufzugsglocke. |
| `sfx_van_depart` | 1,2–2 s | Fahrzeug startet und fährt los. |
| `sfx_van_arrive` | 0,8–1,5 s | Bremsen, Tür klappt. |
| `sfx_scooter_horn` | 0,3–0,5 s | Hupe, frech. |
| `sfx_ink` | 0,3–0,6 s | Füller kratzt eine Zeile ins Kassenbuch (jede Buchung). |
| `sfx_coins` | 0,4–0,8 s | Münzen klimpern (Geld kommt). |
| `sfx_order_new` | 0,5–0,9 s | Brief rutscht in den Briefkasten. |
| `sfx_order_paid` | 0,8–1,2 s | Kassenglocke und Münzregen. |
| `sfx_order_failed` | 0,6–1 s | Stempel knallt, Papier wird zerknüllt. |
| `sfx_shelf_full` | 0,5–0,8 s | Kisten rutschen, dumpfer Stoß. |
| `sfx_upgrade` | 0,4–0,7 s | Schraube festgezogen, kleines Pling. |
| `sfx_rebuild` | 1,5–2,5 s | Umbau: Hämmern, Sägen, Ruck, Glocke. |
| `sfx_hire` | 0,8–1,2 s | Handschlag, Stuhl rückt, „Hm-hm!“ (ohne Worte). |
| `sfx_unlock_floor` | 1,5–2 s | Bretter brechen, Staub, Tusch. |
| `sfx_chapter` | 2–3 s | Siegel ins Wachs, Glocke, kleine Fanfare. |
| `sfx_attention_up` | 0,6–1 s | Polizeipfeife in der Ferne. |
| `sfx_attention_down` | 0,6–1 s | Erleichtertes Ausatmen, Grillen. |
| `sfx_siren` | 2–3 s, schleifbar | Altmodische Sirene, gedämpft. |
| `sfx_club_start` | 1–2 s | Tür öffnet sich, Swing bricht herein. |
| `sfx_ability` | 0,6–1 s | Aufziehen einer Uhr, Zing. |
| `sfx_challenge_start` | 1–2 s | Turmuhr schlägt, Nebelhorn darunter. |
| `sfx_challenge_won` | 1,5–2,5 s | Blechbläser-Fanfare, gedämpft. |
| `sfx_tap` | 0,05–0,15 s | Leiser Holzklick (jeder Tipp). |
| `sfx_ui_open` | 0,2–0,4 s | Seite blättert (Fenster öffnet sich). |
| `sfx_ui_close` | 0,2–0,4 s | Buch klappt leise zu. |
| `sfx_reject` | 0,3–0,5 s | Dumpfes „Nö“ auf einer Tuba. |
| `sfx_purchase` | 0,8–1,2 s | Kasse klingelt, Funkeln (Einkauf im Shop). |
| `sfx_reward` | 0,8–1,2 s | Geschenk wird ausgepackt. |

**Atmosphären (30–60 s, nahtlos):** `amb_street` (Regen, ferne Straßenbahn, Hund bellt), `amb_cellar` (Tropfen,
Lüfter, gedämpfte Straße), `amb_lab` (Blubbern, Zischen), `amb_club` (Bass durch die Wand, Gläser), `amb_villa`
(Kaminfeuer, Uhr tickt, Klavier fern).

**Musik (90–150 s, nahtlos, Swing/Jazz im Cartoon-Takt, Kontrabass, Besen, gestopfte Trompete, Klavier):**
`music_main` (ersetzt die bestehende Datei), `music_oldtown`, `music_docks`, `music_night`, `music_crown`,
`music_prologue` (ruhig, Klavier und Regen), `music_finale` (festlich, Bigband), `music_challenge` (gehetzt,
schneller Swing).

## 15. Abgabe

1. **Ein Commit pro Abschnitt** (1 bis 14), Nachricht „assets: Abschnitt N – Titel“, auf den Branch pushen.
2. `docs/asset-credits.json` für **jede** Datei.
3. Vor dem Push selbst prüfen: Name exakt, Maß exakt, PNG mit Alpha nur bei Sprites, Sprite-Blätter gleichmäßig,
   Figur in jedem Bild an derselben Stelle, Blick nach rechts, keine Schrift, keine Marken, kein Konsum.
4. Am Ende eine Liste: was geliefert ist, was nicht und warum. Danach baue ich alles ein und prüfe es in den
   Screenshots.
