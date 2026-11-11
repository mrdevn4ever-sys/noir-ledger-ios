# Auftrag an Hermes: Ton und Bilder für NOIR LEDGER (iOS)

Du lieferst Dateien in ein bestehendes Git-Repository. Der Spielcode ist fertig und sucht diese Dateien **nach Namen**.
Stimmt ein Name oder ein Maß nicht, wird die Datei ignoriert oder falsch dargestellt. Halte dich deshalb exakt an die
Tabellen. Du schreibst **keinen Swift-Code** und änderst keine bestehenden Dateien außer den hier genannten.

## 1. Das Spiel in drei Sätzen

NOIR LEDGER ist ein Idle-Tycoon für iPhone (Hochformat). Der Spieler erbt einen Kellerbetrieb in der erfundenen
Flussstadt Varnholm und baut ein Untergrund-Imperium auf: vier erfundene Waren (Glimmer, Cinder, Velvet, Halo), fünf
Bezirke, Geldwäsche-Frontbetriebe, Polizei-Druck („Heat“). Ton: erwachsen, ernst, Film noir, 1930er bis 1950er, Regen,
Nacht, europäische Altstadt.

## 2. Stil, der für alles gilt

**Farben (Hex, bitte einhalten):**

| Rolle | Farbe |
| --- | --- |
| Grund, tiefste Schatten | `#0F0D0B`, `#07060A` |
| Wände, Flächen | `#17140F`, `#1D1712`, `#2A1D14` (Leder) |
| Warmes Licht, Geld, Glimmer | `#E0A43A` (Bernstein), `#C8A55A` (Altgold) |
| Messing, Metallteile | `#D19E4A`, `#8C6630` |
| Papier, Glühbirne | `#E6D8B8` |
| Cinder (Glut) | `#D8742E` |
| Velvet (Pflaume) | `#A77BC0` |
| Halo (Eis) | `#9FD3E0` |
| Kaltes Stadtlicht | `#8FA6A0` |
| Rot nur für Gefahr | `#E0483C` |

**Bildsprache:** dunkel, wenig Licht, eine warme Lichtquelle pro Raum, starke Schatten, leichter Dunst, nasse
Oberflächen. Gemalt-realistisch oder stilisiertes 3D, aber einheitlich über alle Bilder.

**Verboten:** echte Drogen, Spritzen, Pillen, Pulverlinien, Hanfblätter, Konsum; echte Marken, Logos, Firmennamen;
lesbare Schrift im Bild (Schilder nur als Leuchtrahmen ohne Text); Waffen im Vordergrund, Blut, Gewalt; Gesichter
realer Personen; Comic-Look, Emojis; Wasserzeichen.

## 3. Lizenz (ohne Ausnahme)

Erlaubt ist nur:

1. selbst erzeugt (Blender, eigene Synthese, eigene Aufnahme),
2. **CC0 / Public Domain**,
3. KI-erzeugt nur, wenn die Nutzungsbedingungen des Dienstes kommerzielle Nutzung ohne Namensnennung erlauben.

Nicht erlaubt: CC-BY, CC-BY-NC, „royalty free“ mit Einschränkungen, Material aus Spielen, Filmen oder Sample-Packs mit
unklaren Rechten.

Für **jede** gelieferte Datei einen Eintrag in `docs/asset-credits.json`:

```json
[
  { "file": "App/Resources/Audio/sfx_buy.m4a", "origin": "own synthesis in Audacity", "license": "own work", "source_url": "" },
  { "file": "App/Resources/Audio/amb_rain.m4a", "origin": "freesound.org, user X, sound 123456", "license": "CC0-1.0", "source_url": "https://…" }
]
```

## 4. Ton

Ordner: `App/Resources/Audio/`. Dort liegen bereits synthetische `.wav`-Dateien mit denselben Namen. Deine Datei
**ersetzt** sie: Lege deine `.m4a` ab und **lösche die gleichnamige `.wav`**.

Format für alle: AAC in `.m4a`, 44,1 kHz. Effekte mono, Musik und Regen stereo. Kein Knacken am Anfang oder Ende,
keine Stille davor (höchstens 10 ms).

### 4.1 Effekte (Spitzenpegel −3 dBFS, trocken, kurz)

| Datei | Wann es spielt | Klang | Länge |
| --- | --- | --- | --- |
| `sfx_tap.m4a` | Spieler tippt auf einen Raum, oft schnell hintereinander | leiser, trockener Klick: Holz, Werkzeug auf Werkbank | 40–80 ms |
| `sfx_buy.m4a` | Ausbau gekauft | zwei Münzen auf Holz, kurz und hell | 150–250 ms |
| `sfx_milestone.m4a` | Linie erreicht Meilenstein (Ertrag ×2) | Registrierkasse mit Glocke, danach heller Akkord | 0,8–1,2 s |
| `sfx_reject.m4a` | Aktion nicht möglich (zu teuer) | dumpfes, tiefes „Nein“: gedämpfter Holzschlag | 120–200 ms |
| `sfx_claim.m4a` | Belohnung abgeholt | Umschlag wird aufgerissen, zwei aufsteigende Töne | 300–500 ms |
| `sfx_chapter.m4a` | Kapitel abgeschlossen | schwerer Stempel aufs Papier, dann warmer Moll-Akkord (Klavier oder Rhodes) | 1,2–1,8 s |
| `sfx_raid.m4a` | Razzia | Tür wird eingetreten, tiefer Schlag, kurzes Durcheinander ohne Stimmen | 1,0–1,5 s |
| `sfx_alarm.m4a` | Ermittlung beginnt | ferne alte Polizeisirene (europäisch, zweitönig), gedämpft wie durch ein Fenster | 0,8–1,2 s |
| `sfx_decision.m4a` | Entscheidung liegt vor | Papier raschelt, Brief wird auf den Tisch gelegt | 300–500 ms |
| `sfx_prestige.m4a` | Abtauchen / Neuanfang | anschwellendes Rauschen (Zug fährt ein), dann klarer Glockenakkord | 1,5–2,2 s |
| `sfx_purchase.m4a` | Echtgeld-Kauf erfolgreich | hochwertige Kassenglocke, Schublade springt auf | 500–800 ms |
| `sfx_boost.m4a` | Boost gestartet | Streichholz wird angerissen und flammt auf | 400–700 ms |

### 4.2 Flächen (müssen nahtlos loopen)

| Datei | Inhalt | Länge | Lautheit |
| --- | --- | --- | --- |
| `amb_rain.m4a` | gleichmäßiger Regen auf Kopfsteinpflaster und Blechdach, ferne Stadt, **kein** Donner, keine Stimmen, keine Autos | 30–60 s | −28 LUFS |
| `music_main.m4a` | langsamer Noir-Jazz, 65–80 bpm, Moll: gezupfter Kontrabass, Besen-Schlagzeug, gedämpfte Trompete oder Tenorsax, sparsames Klavier. Ruhig genug für stundenlanges Hören, keine auffällige Melodie, die nervt | 90–150 s | −18 LUFS |

Loop-Test: Datei zweimal hintereinander in eine Spur legen. An der Nahtstelle darf man nichts hören.

## 5. Bilder

Jedes Bild kommt als **eigener Ordner** in `App/Resources/Assets.xcassets/`. Beispiel für `RoomGlimmer0`:

```
App/Resources/Assets.xcassets/RoomGlimmer0.imageset/
  RoomGlimmer0.png
  Contents.json
```

`Contents.json` (Name der PNG anpassen, sonst nichts):

```json
{
  "images": [
    { "filename": "RoomGlimmer0.png", "idiom": "universal" }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```

Alle Bilder: PNG, sRGB, 8 Bit. Das Spiel schneidet die Bilder mittig zu (links/rechts fällt je nach Gerät etwas weg):
**wichtige Inhalte in die mittleren 85 % der Breite.**

### 5.1 Produktionsräume (16 Bilder)

Seitenansicht eines Raums wie in einem aufgeschnittenen Haus, Kamera exakt frontal (orthografisch), Blick auf die
Rückwand. **1536 × 480 px.**

Pflicht für jeden Raum, weil das Spiel darüber zeichnet:

- **Keine Menschen im Bild.** Die Arbeiter kommen als eigene Animation (5.3).
- **Unteres Fünftel (ab 82 % der Höhe) ist dunkler, leerer Boden.** Dort laufen im Spiel Kisten auf einem Band.
- **Oben links (erste 45 % der Breite, obere 35 % der Höhe) ruhig und dunkel.** Dort steht Text.
- Die Arbeiter stehen später bei 20 %, 50 %, 66 % und 84 % der Breite mit den Füßen auf 82 % der Höhe, 211 px groß.
  An diesen Stellen keine hohen Gegenstände im Vordergrund.

Vier Ausbaustufen pro Ware, gleicher Raum, gleiche Kamera, es kommt nur Ausstattung dazu:

| Stufe | Zustand |
| --- | --- |
| 0 | karger Keller, eine nackte Glühbirne, eine Werkbank mit dem Gerät |
| 1 | Regale mit Kisten an der Rückwand, zweites Gerät |
| 2 | Rohre an der Decke, zweite Lampe, ordentlicher Arbeitsplatz |
| 3 | voll ausgebaute Manufaktur, Leuchtrahmen an der Wand in der Farbe der Ware (ohne Schrift), Messing-Details |

| Dateiname | Ware | Gerät im Raum | Lichtfarbe |
| --- | --- | --- | --- |
| `RoomGlimmer0` … `RoomGlimmer3` | Glimmer (billige Straßenware) | Glaskolben und Flaschen mit bernsteinfarbener Flüssigkeit auf einer Werkbank | Bernstein `#E0A43A` |
| `RoomCinder0` … `RoomCinder3` | Cinder (Massenware für Hafen und Werk) | gemauerter Ofen mit glühender Klappe, Ofenrohr | Glut `#D8742E` |
| `RoomVelvet0` … `RoomVelvet3` | Velvet (Ware für Clubs) | Kupferkessel mit Spiralrohr und Auffangglas | Pflaume `#A77BC0` |
| `RoomHalo0` … `RoomHalo3` | Halo (Luxusware) | feine Glasapparatur mit ringförmigen Glasteilen auf einem Stativ, sauber wie ein Labor | Eis `#9FD3E0` |

Die Geräte sind bewusst abstrakt und altmodisch (Destille, Ofen, Glaslabor). Nichts, was an eine echte Herstellung
erinnert.

**Blender-Vorgehen (empfohlen):** eine Szene pro Ware, vier Collections für die Stufen, die nacheinander
eingeblendet werden. Kamera orthografisch, Bildformat 1536 × 480. Cycles, 256 Samples, Denoise an. Licht: ein
Punktlicht 2700 K als Glühbirne (im Bild sichtbar, oben bei 24 % der Breite), ab Stufe 2 ein zweites bei 74 %; dazu
ein schwaches Emissionsmaterial in der Warenfarbe am Gerät. Volumetrischer Dunst (Dichte 0,02). Color Management:
Filmic, Look „Medium High Contrast“, Belichtung −0,5. Rückwand: Ziegel, dunkel. Kein Tageslicht.

### 5.2 Zwei Hintergründe

| Dateiname | Größe | Inhalt |
| --- | --- | --- |
| `SceneStreet` | 1440 × 528 px | nächtliche Straße in Varnholm im Regen, frontal. Obere 80 %: Häuserzeile und dahinter die Silhouette der Altstadt mit einzelnen warm leuchtenden Fenstern. Untere 20 %: nasse, dunkle, **leere** Fahrbahn (das Spiel lässt dort einen Lieferwagen fahren und zeichnet Leuchtschilder auf Höhe 76–80 %). Keine Autos, keine Menschen, keine lesbaren Schilder. Unten links ruhig und dunkel (dort steht eine große Zahl). |
| `SceneStash` | 1488 × 240 px | nur die Rückwand eines Lagerkellers: dunkler Ziegel, etwas Licht von oben. **Keine Regale, keine Kisten** (die zeichnet das Spiel). |

### 5.3 Arbeiter-Animation (1 Bild)

`SpriteWorker`: ein Streifen aus **8 Einzelbildern nebeneinander**, jedes **256 × 320 px**, zusammen **2048 × 320 px**,
PNG **mit transparentem Hintergrund**.

- Eine Figur von der Seite, nach rechts gewandt: langer Mantel, Hut mit Krempe, kein erkennbares Gesicht.
- Fast schwarz (`#090807`) mit schmaler warmer Lichtkante (`#E0A43A`) an Hut, Schulter und Arm.
- Bewegung: arbeitet mit dem rechten Arm an einer unsichtbaren Werkbank vor sich (heben, senken, greifen). Die 8
  Bilder ergeben eine Schleife; Bild 8 geht fließend in Bild 1 über. Abspielgeschwindigkeit im Spiel: 10 Bilder pro
  Sekunde.
- Die Füße stehen in jedem Bild an derselben Stelle auf der Unterkante. Die Figur füllt die Höhe zu etwa 95 % und ist
  in jedem Bild waagerecht mittig.
- Blender: geriggte Low-Poly-Figur, Kamera orthografisch von der Seite, transparenter Film, ein Rim-Light von hinten
  rechts in Bernstein. 8 Frames rendern und zu einem Streifen zusammensetzen (ImageMagick:
  `magick frame_*.png +append SpriteWorker.png`).

## 6. Abgabe

1. Arbeite auf dem Branch, den der Auftraggeber dir nennt. Ein Commit für Ton, einer für Bilder.
2. Führe vor dem Commit im Repository aus und stelle sicher, dass alle drei mit `…_OK` enden:

   ```
   python3 scripts/check_l10n.py
   python3 scripts/shared_assets.py check
   python3 scripts/scan_repo.py
   ```

3. Prüfe selbst: jede Datei aus den Tabellen ist da, heißt exakt so, hat exakt die Maße; jede `.wav`, die du ersetzt
   hast, ist gelöscht; `docs/asset-credits.json` hat für jede Datei einen Eintrag.
4. Schreibe am Ende eine kurze Liste: gelieferte Dateien, Quelle und Lizenz je Datei, und was du **nicht** liefern
   konntest und warum. Liefere lieber eine Datei weniger als eine mit unklarer Lizenz.

## 7. Reihenfolge, falls die Zeit knapp wird

1. `music_main` und `amb_rain` (größte Wirkung)
2. die zwölf Effekte
3. `RoomGlimmer0`–`3` und `SpriteWorker` (der Spieler sieht sie in den ersten Minuten)
4. `SceneStreet`
5. die übrigen zwölf Räume, zuletzt `SceneStash`
