# NOIR LEDGER 4.0 — Wirtschaft, Tempo, Testergebnisse

Alle Zahlen sind **Balancing-Hypothesen**, bis echte Spieltests sie bestätigen. Sie stehen als anpassbare Daten in
`Packages/NoirCore/Sources/NoirCore/Flow/FlowContent.swift`; die Simulation zum Abstimmen liegt in den Core-Tests
(`FlowTests.pacing`, ein Bot-Spieler) und als Python-Modell (Langzeitprofile bis Tag 30).

## Der Warenfluss

```
Werkbank (pro Ware) → Regal (pro Ware) → Wagen (gemeinsam) → Abnehmer (pro Viertel) → Kassenbuch
```

- Erst die **verbuchte Lieferung** bringt Geld. Eine Lieferung zahlt den Abnehmer mit dem besten Preis zuerst.
- Verkauf im eingeschwungenen Zustand = **min(Werkbank, Wagen, Abnehmer)**, und der Wagen nimmt pro Fahrt höchstens,
  was im Regal liegt (zu kleines Regal = eigener Engpass).
- Beispiel aus dem Auftrag, genau so im Spiel: Werkbank 12/Min, Wagen 6/Min, Abnehmer 10/Min → verkauft 6, das Regal
  füllt sich um 6/Min. Wagen +1 Stufe → 12/Min Kapazität → verkauft 10. Werkbank-Ausbau allein → nur mehr Vorrat.
- Jede Ausbau-Vorschau rechnet mit derselben Funktion wie die Simulation (`Flow.forecast`). Ein Test vergleicht die
  Vorschau mit 20 Minuten echter Simulation (±3 %).
- Gemeinsamer Wagen: Jede Ware mit Bedarf bekommt **20 % Grundanteil**, den Rest verteilt die Reihenfolge, die der
  Spieler festlegt. Angenommene Aufträge fahren standardmäßig vor den Stammkunden (umschaltbar).

## Stationen

Kapazität einer Stufe: `Stufe × 2^(erreichte Meilensteine)`, Meilensteine bei 10, 25, 50, 100, 150, 200, 300, 400,
500, 750, 1000 (sichtbarer Umbau). Preis: `Basis × Wachstum^(Stufe−1)`, Mehrfachkauf ×1/×10/×100/MAX.

| Ware | Preis/Kiste | Gewicht | Takt | Kisten/Takt (Stufe 1) | Werkbank ab | Wachstum | Regal (Stufe 1) | Werkstatt öffnen | Werkstattleitung | ab Kapitel |
|---|---|---|---|---|---|---|---|---|---|---|
| Gras | 5 | 1 | 5 s | 1 | 20 | 1,15 | 20 | – | 100 (Jonas Brandt) | 1 |
| Crystal | 60 | 2 | 8 s | 4 | 25 Tsd. | 1,13 | 60 | 400 Tsd. | 150 Tsd. (Dario Feld) | 3 |
| Pillen | 900 | 1 | 6 s | 3 | 2,5 Mio. | 1,13 | 40 | 30 Mio. | 12 Mio. (Mira Kessler) | 4 |
| Koks | 24 Tsd. | 0,5 | 10 s | 1 | 250 Mio. | 1,13 | 15 | 4 Mrd. | 1 Mrd. (Hanna Wolff) | 5 |

Wagen: 1 Einheit pro Fahrt auf Stufe 1, Fahrt 10 s, ab 20, Wachstum 1,14. Disponent (Emil Varga): 300.
Regal: Wachstum 1,30.

| Abnehmer | Ware | Viertel | Kisten/Min (Stufe 1) | Preisfaktor | Gewinnen | Ausbau ab | ab Kapitel | Besonderheit |
|---|---|---|---|---|---|---|---|---|
| Ecke Mühlgasse | Gras | Mühlgasse | 10 | 1,0 | – | 25 | 1 | |
| Bäckerei im Hinterhof | Gras | Mühlgasse | 8 | 1,5 | 400 | 60 | 1 | Adressbuch-Start |
| Altmarkt | Gras | Altstadt | 30 | 1,3 | 3 Tsd. | 400 | 2 | |
| Universität | Gras | Altstadt | 45 | 1,1 | 20 Tsd. | 2 Tsd. | 2 | |
| Kai 7 | Crystal | Hafen | 40 | 1,0 | – | 30 Tsd. | 3 | |
| Das Werk | Crystal | Hafen | 80 | 0,9 | 2 Mio. | 200 Tsd. | 3 | |
| Club Lumen | Pillen | Nachtviertel | 30 | 1,0 | – | 3 Mio. | 4 | Clubnächte |
| Varieté Rosalie | Pillen | Nachtviertel | 40 | 1,2 | 100 Mio. | 20 Mio. | 4 | Clubnächte |
| Villa am See | Koks | Oberstadt | 6 | 1,0 | – | 300 Mio. | 5 | Vertrauen |
| Senatorenclub | Koks | Oberstadt | 8 | 1,4 | 20 Mrd. | 4 Mrd. | 5 | Vertrauen |

Clubnacht: alle 8 Minuten für 3 Minuten (Greta Lind: +1 Minute) Nachfrage ×3 und Preis ×1,5, sonst Nachfrage ×0,4.
Vertrauen 0–5: +10 % Preis je Stufe; pünktlicher Vertrauensauftrag +1, verpasster −1.

## Aufmerksamkeit (pro Viertel, 0–100)

| Stufe | ab | Folge |
|---|---|---|
| Ruhig | 0 | – |
| Beobachtet | 30 | Abnehmer im Viertel nehmen 25 % weniger |
| Heiß | 60 | nehmen die Hälfte und zahlen 15 % weniger |
| Abgetaucht | 85 | kaufen nichts, bis es ruhiger wird |

Sinkt um 3 pro Minute (auch offline), mit **Ruhepause** dreimal so schnell (dafür keine Lieferungen dorthin), mit
Viktor Sand anderthalbmal so schnell. Ruhige Aufträge −5. Keine Razzia, kein Geldverlust: alle Folgen sind
reversibel. Automatisch angenommen werden (mit Sami Okafor) nur ruhige Aufträge.

## Aufträge

| Art | Zahlung (× Warenwert) | Aufmerksamkeit | Menge | Frist |
|---|---|---|---|---|
| Ruhig | ×1,0 | −5 | 1–2 Minuten Absatz | 120 s + 3 × Lieferzeit |
| Auffällig | ×1,45 | +20 | 1–2 Minuten Absatz | wie ruhig |
| Großauftrag (ab Kap. 3) | ×1,9 | +35 | 5 Minuten Absatz | 120 s + 2,5 × Lieferzeit |
| Vertrauen (ab Kap. 5) | ×1,6 | +10 | 1,5 Minuten Koks | |
| Stadtauftrag (Kap. 6) | ×2,5 | +15 in jedem betroffenen Viertel | jede offene Ware 1,5 Min. | |
| Der letzte Vertrag | ×3,0 | 0 | jede Ware 10 Min. | 10 Min. + 2 × Lieferzeit |

Erster Auftrag im Keller (Prototyp aus dem Auftrag): dieselben 20 Kisten Gras, **100 ruhig oder 145 mit +20**.
Verpasst: Gelieferte Kisten werden zum üblichen Preis bezahlt, Kisten unterwegs gehen an die Stammkunden.

## Kapitel

| Kapitel | Ort | Person | Ziele | Wer kommt dazu |
|---|---|---|---|---|
| 1 Leopolds Keller | Mühlgasse | Jonas Brandt | 1 Lieferung, Werkstattleitung, 1 Sonderauftrag, Disponent, 6 Tsd. verdient | Sami Okafor (Kontaktperson) |
| 2 Altstadt | Altstadt | Sami Okafor | Altmarkt gewinnen, 5 Sonderaufträge, 60 Kisten Gras/Min, 60 Tsd. | Ilse Morgen (+15 % auf Sonderaufträge) |
| 3 Hafen | Hafen | Dario Feld | Crystal öffnen + Leitung, 1 Großauftrag, 50 Mio. | Viktor Sand (Aufmerksamkeit ×1,5 schneller weg) |
| 4 Nachtviertel | Nachtviertel | Greta Lind | Pillen öffnen + Leitung, 150 Pillen in einer Clubnacht, 20 Mrd. | Greta Lind (Clubnacht +1 Min.) |
| 5 Oberstadt | Oberstadt | Anton Kraus | Koks öffnen + Leitung, Vertrauen 3 bei einem Kunden, 600 Mrd. | Anton Kraus (ruhiges Wort −40) |
| 6 Varnholm | ganze Stadt | Mira Kessler | 3 Stadtaufträge, 10 Bio., der letzte Vertrag | – (Finale) |

Jedes abgeschlossene Kapitel: alle Einnahmen ×1,5. Ab Kapitel 3: aktive Fähigkeiten (Doppelschicht, Eilfahrt je
1 Min., 10 Min. Abklingzeit). Nach dem Finale drei Herausforderungen (Nebel am Hafen, Pressewoche, Streik im Werk)
mit je drei Zielen, Gefallen als Belohnung und dauerhaft +10 % pro komplett geschaffter Herausforderung (max. +30 %).

## Abwesenheit

Bis 12 Stunden angerechnet (mit stillem Teilhaber 24), sekundengenau simuliert: nur Stationen mit Personal arbeiten,
echte Bestände, laufende Aufträge behalten ihre Frist (nie rückwirkend erfüllt), Aufmerksamkeit sinkt, Effekte laufen
aus. Die Abrechnung wird einmal gebucht und im Spielstand gespeichert; erneutes Öffnen zeigt sie, zahlt aber nicht
noch einmal. Rückwärts gestellte Uhr: nichts angerechnet. Ein Test prüft 2 Stunden gegen die Vorschau (±3 %).

## Tempo: Ziel und Messung

Bot-Spieler in den Core-Tests (Swift, echte Regeln, 0,6 s Reaktionszeit):

| Start | erste Lieferung | erste Automatisierung | volle Kette | Kapitel 1 |
|---|---|---|---|---|
| Ziel | 15–30 s | 2–4 Min. | 6–10 Min. | 15–25 Min. |
| Geldkassette | 0,3 Min. | 1,5 Min. | 7,5 Min. | 16,3 Min. |
| Adressbuch | 0,3 Min. | 2,6 Min. | 8,9 Min. | 17,7 Min. |
| Werkzeug | im CI-Lauf gemessen | | | |

Python-Langzeitmodell (vereinfacht: nach der ersten Sitzung alles automatisiert, drei Sitzungen am Tag):

| Profil | Kap. 2 | Kap. 3 | Kap. 4 | Kap. 5 | Finale | Tag 1 | Tag 7 | Tag 30 |
|---|---|---|---|---|---|---|---|---|
| aktiv (3 Sitzungen, 2 h/Tag) | 0,4 Tage | 0,8 | 3,4 | 8,4 | 18,8 | Kap. 4, 222 Tsd./Min | Kap. 5, 115 Mio./Min | durch, 1,4 Mrd./Min |
| überwiegend offline (3 × 4 Min.) | 0,3 | 0,9 | 3,3 | 8,3 | 18,9 | Kap. 4 | Kap. 5 | durch |
| unausgewogen (nie Abnehmer ausgebaut) | 0,4 | 0,8 | 21,4 | – | – | Kap. 4 | hängt in Kap. 4 | Kap. 5 |

Lesart: Wer offline spielt, kommt fast gleich schnell voran (Personal arbeitet 12 h). Wer die Abnehmer ignoriert,
bleibt stecken, bis er sie ausbaut: Das ist die Entscheidung, die das Spiel tragen soll. Der komplette Weg bis zum
Finale ist ohne Käufe und ohne Werbung erreichbar.

## Offene Punkte

- **Echte Spieltests fehlen.** Alle Zeiten stammen aus Bots und Modellen; D1/D7-Werte erst aus echten Daten.
- **Bilder:** Altstadt nutzt vorerst das Werk-Bild; Werkbank-Umbaustufen, Regal-Füllstände, Wagen und
  Kassenbuchseite sind gezeichnet bzw. aus 2.x-Bildern zusammengesetzt. Auftrag an Hermes liegt bei.
- **Geschäftsplan nach Kapiteln** (optionaler Umbau statt Neustart) ist nicht gebaut: Erst prüfen, ob er Entscheidungen
  schafft, die die Herausforderungen nicht schon bieten.
- **Langzeit nach Tag 20:** Einnahmen flachen ab; nach dem Finale tragen nur die Herausforderungen.
- **Monetarisierung** unverändert aus 3.x (Werbebonus nach freier Abrechnung, Premium ×2, No-Ads, Gefallen); die
  Wirkung auf die neue Wirtschaft ist noch nicht gemessen.
