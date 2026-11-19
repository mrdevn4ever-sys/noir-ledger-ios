# Auftrag an Hermes: Bilder und Ton für NOIR LEDGER 4.0

Du lieferst Dateien in das Repository `mrdevn4ever-sys/noir-ledger-ios`, Branch `claude/exciting-cori-5r0kcv`.
Du schreibst **keinen Swift-Code**. Lizenzregeln, Stil und Farben wie im ersten Auftrag (`docs/HERMES_ASSET_BRIEF.md`,
Abschnitte 2 und 3); jede Datei bekommt einen Eintrag in `docs/asset-credits.json`.

## Worum es jetzt geht

4.0 zeigt den Warenfluss wie eine Fabrik von der Seite: **Werkbank → Regal → Wagen → Abnehmer im Viertel →
Kassenbuch.** Der Spieler muss auf einen Blick sehen, wo es sich staut. Varnholm, 1947, Regen, Film noir. Die Waren
sind Gras, Pillen, Crystal und Koks (Entscheidung des Besitzers); gezeigt wird Ware in Kisten, Säcken, Dosen,
**nie Konsum**, keine Spritzen, keine Pulverlinien, keine lesbare Schrift, keine Marken.

## Bilder

Format: PNG, sRGB, 8 Bit. „Platte“ = ohne Transparenz. „Sprite“ = mit Transparenz, Motiv freigestellt.
Lege jedes Bild als Imageset an: `App/Resources/Assets.xcassets/<Name>.imageset/` mit der PNG und einer
`Contents.json` wie bei `RoomGlimmer0.imageset` (eine Datei, `"idiom": "universal"`).

| Name | Typ | Maß (px) | Motiv |
|---|---|---|---|
| `QuarterCellars` | Platte | 1440 × 528 | Mühlgasse bei Nacht: Kellertreppe, nasse Pflastersteine, eine Ecke mit Laterne, Leopolds Kellerfenster mit warmem Licht. |
| `QuarterOldTown` | Platte | 1440 × 528 | Altstadt: Marktplatz mit leeren Ständen im Regen, Fachwerk, im Hintergrund die Universität (Kuppel, Säulen). |
| `QuarterDocks` | Platte | 1440 × 528 | Hafen: Kräne im Nebel, Kisten auf dem Kai, ein Frachter, Schichtlicht, im Hintergrund ein Stahlwerk mit Schloten. |
| `QuarterNight` | Platte | 1440 × 528 | Nachtviertel: Clubeingang mit Leuchtrahmen ohne Text, Schlange im Regen, Varieté-Vordach, Pflaumen-Neon (#A77BC0). |
| `QuarterCrown` | Platte | 1440 × 528 | Oberstadt: Villa am See mit erleuchteten Fenstern, Limousine, Kies, eisblaues Mondlicht (#9FD3E0). |
| `ScenePrologue` | Platte | 1206 × 900 | Notarbüro, 1947: Schreibtisch, darauf ein alter Schlüssel, eine Karte mit Adresse (unlesbar), ein ledergebundenes Kassenbuch; Regen am Fenster, Schreibtischlampe. Kein Gesicht im Bild. |
| `PropCrate` | Sprite | 128 × 128 | Eine Holzkiste von vorn, leicht von oben, Bernsteinlicht von links. Wird zehnmal nebeneinander als Regalfüllung gezeigt. |
| `PropCrateEmpty` | Sprite | 128 × 128 | Derselbe Regalplatz leer: nur Brett und Schatten. |
| `PropVan` | Sprite | 640 × 280 | Lieferwagen der 1940er von der Seite, Fahrtrichtung rechts, dunkelgrün-schwarz, Scheinwerfer an, nass, ohne Schrift. |
| `PropLedgerPage` | Platte | 1024 × 1024 | Aufgeschlagene Kassenbuchseite, nahtlos kachelbar: vergilbtes Papier (#E6D8B8), feine Linien, ein Tintenfleck am Rand, keine Schrift. |
| `BenchWeed1`, `BenchWeed2`, `BenchWeed3` | Platte | 1536 × 480 | Gras-Werkstatt in drei Ausbaustufen (bei Stufe 10, 25, 50): 1 eine staubige Werkbank mit ein paar Töpfen unter einer Glühbirne, 2 eine zweite Werkbank und Pflanzlampen, 3 eine ganze Reihe mit Bewässerung und Arbeitern. Der Raum bleibt derselbe, nur die Einrichtung wächst. |
| `BenchCrystal1`–`3`, `BenchPills1`–`3`, `BenchCoke1`–`3` | Platte | 1536 × 480 | Dasselbe für Crystal (Laborkessel, Kühlschlangen, Kisten mit blauen Kristallen), Pillen (Tablettenpresse, Dosen, Pflaumenlicht), Koks (Waage, gepresste Blöcke in Papier, eisblaues Licht). Jeweils drei Stufen im selben Raum. |

Die Ausbaustufen sind das Wichtigste: Ein Spieler muss sehen, dass seine Werkbank nach dem Umbau anders aussieht.
Die vorhandenen `Room…0–3`-Bilder bleiben als Ersatz, bis deine Stufen da sind.

## Ton

Ordner `App/Resources/Audio/`, AAC in `.m4a`, 44,1 kHz, mono, Lautheit um −16 LUFS, Stille am Anfang abgeschnitten.

| Datei | Länge | Klang |
|---|---|---|
| `sfx_bench.m4a` | 0,4–0,8 s | Werkbank: kurzes Holz-Klonk mit leisem Mechanik-Klicken. Läuft oft, darf nicht nerven. |
| `sfx_van.m4a` | 1,5–2,5 s | Alter Lieferwagen springt an und fährt im Regen los, leise. |
| `sfx_ink.m4a` | 0,3–0,6 s | Füller kratzt eine Zeile ins Kassenbuch. Das ist der Klang einer Buchung. |
| `sfx_order.m4a` | 0,8–1,2 s | Gedämpfte Registrierkassen-Glocke und Münzen: ein Auftrag ist bezahlt. |
| `sfx_shelf_full.m4a` | 0,5–0,9 s | Eine Kiste rutscht gegen eine volle Regalwand: dumpfer Holzstoß. |
| `amb_cellar.m4a` | 30–60 s, nahtlos | Keller: Regen von draußen, Tropfen, ferne Straßenbahn, ganz leise Maschine. |

## Abgabe

1. Dateien committen und auf den Branch pushen, ein Commit pro Gruppe (Viertel, Werkbänke, Requisiten, Ton).
2. `docs/asset-credits.json` ergänzen.
3. Nichts anderes ändern. Ich baue die Bilder und Klänge danach ein und prüfe sie in den Screenshots.
