# NOIR LEDGER · Zerlegung der spielbaren iOS-Fassung

**Entscheidung: Gebäude und Warenfluss behalten. Einstieg und Fortschrittsanzeige umbauen. Den Geschäftsplan neu bauen – aber nicht zuerst.** Das Spiel hat schon eine gute Frage: *Warum kommt trotz voller Werkbank nicht mehr Geld an?* Seine beste Antwort steckt in einem Ausbau-Fenster. Die erste Minute sollte genau diese Erfahrung verkaufen, nicht den Weg dorthin erklären. Mehr Partikel oder ein weiterer Multiplikator allein lösen das nicht.

## Was tatsächlich geprüft wurde

- **Spielstand des Codes:** `1d695653c3929c236c74b9d6bd192593d338ef52`. Relevant sind `Flow/`, `LedgerStore`, `Scene/` und die angeschlossenen Sheets. `PRODUCT.md`, `DESIGN.md`, `ARCHITECTURE.md`, `QA.md` und `SAVE_FORMAT.md` enthalten ältere Verträge. Die Änderungen im `IOS_GAME_BRIEF.md`, die 4.x-Briefs und vor allem die erreichbare App haben Vorrang. Ein bestandener alter NG+-Bot ist **kein Prestige-Nachweis für Flow**.
- **Bildbelege:** [iOS-Lauf](https://github.com/mrdevn4ever-sys/noir-ledger-ios/actions/runs/44623932732), [Originale](https://github.com/mrdevn4ever-sys/noir-ledger-ios/tree/17e03c566a22aa95da625b867011fd8f41146ee9/screenshots), [Testübersicht](https://github.com/mrdevn4ever-sys/noir-ledger-ios/blob/17e03c566a22aa95da625b867011fd8f41146ee9/acceptance-report.md): 60 PNGs, 1206 × 2622, iPhone 17 / iOS 26.5, 34/34 App- und UI-Tests zusammen, 151 Core-Tests einschließlich Altversionen. EN/DE-Touren setzen Zustände auf; das ist **kein** durchgehender menschlicher Spieldurchlauf. Referenzen wie `04_upgrade_preview` meinen `de_tour_….png` in diesem Bestand.
- **Tempo:** drei Starts im echten Swift-Kern (`FlowTests.pacing`, Seed 3, Bot mit 0,6 s Reaktionszeit). Startzeit ist **nach** der Erbwahl. Langzeitwerte separat: vereinfachte historische Projektion in `ECONOMY_4.md`, kein gemessenes Spielerverhalten. Keine Aussage über D1/D7, Conversion oder subjektiven Spaß aus einem grünen Test.
- **Noch getrennt prüfen:** Der bisherige Lauf zeigt nicht die spielbare Altstadt als eigenes Kapitel, die Öffnung des vierten Stockwerks, den letzten Vertrag bis zur Auszahlung und eine *laufende* Herausforderung. Ergänzung: `UITests/ChapterTourUITests.swift`, QA-Szenarien `crown` und `contract`, [nativer Prüflauf](https://github.com/mrdevn4ever-sys/noir-ledger-ios/actions/runs/44738468800). Ein Testname gilt nicht als Bildbeleg. Geräteton, Taptic Engine, VoiceOver-Bedienung, echte 120 Hz und ein aktueller öffentlicher Store-Eintrag sind durch Simulatorbilder nicht geprüft.

## Nach Wirkung geordnet

### 1 · Erste 60 Sekunden — **Einstieg neu bauen, Erbschaft behalten**

Im [ersten deutschen Bild](https://github.com/mrdevn4ever-sys/noir-ledger-ios/blob/17e03c566a22aa95da625b867011fd8f41146ee9/screenshots/de_tour_01_prologue.png) stehen Logo, Notar und zehn Zeilen Geschichte **vor** der Entscheidung. Von drei gut unterschiedlichen Startgaben ist nur die Geldkassette angeschnitten sichtbar. „Alles, was legal war, ist schon verkauft“ ist der Satz, den ich retten würde. Er sagt in einem Atemzug mehr über dieses Spiel als ein Tutorial.

Im [Werkzeug-Keller](https://github.com/mrdevn4ever-sys/noir-ledger-ios/blob/17e03c566a22aa95da625b867011fd8f41146ee9/screenshots/de_tour_02_cellar.png) stehen bereits „Tippen!“, „Los!“, ein Ausrufezeichen, zwei Personalpreise, ein Geschenkpunkt und fünf Ziele in der Navigation nebeneinander. Die Werkbank heißt im Bild „Gras“; sichtbar sind Pflanzen. Die richtige Stelle ist markiert, aber zwei gelbe Aufforderungen konkurrieren, bevor eine Kiste im Regal liegt.

| Nach der Erbwahl · Bot, Minuten (gerundet) | Erste verbuchte Lieferung | Werkstattleitung | Erster erfüllter Auftrag | Disponent | Kapitel 1 zu |
|---|---:|---:|---:|---:|---:|
| Geldkassette | 0,3 | 1,5 | 5,3 | 7,5 | 16,3 |
| Adressbuch | 0,3 | 2,6 | 6,4 | 8,9 | 17,7 |
| Werkzeug | 0,3 | 3,7 | 7,4 | 9,6 | 18,5 |

**Die 5-s- und 20-s-Ziele sind verschiedene Tests.** Der erste manuelle Zyklus liefert nach 5 Spielsekunden Ware, nicht Geld. Der Wagen braucht danach 10 s; sein erster Ertrag liegt selbst bei idealer Bedienung nicht innerhalb von 5 s ab Start. Die Geldkassette (+60) finanziert einen Ausbau für 20 sofort. Ohne Geschenk, Video oder Kauf kosten die günstigsten regulären Verbesserungen mindestens 20. Mit einem Wagen für eine Kiste braucht das Adressbuch bei höchstens 7,5 pro Fahrt mindestens drei Fahrten (frühestens 35 s nach Produktionsstart), Werkzeug bei 5 mindestens vier (45 s). Das sind günstige **Untergrenzen**, keine gemessenen UI-Zeiten. Das Werkzeug hebt die Produktion, nicht die Wagenladung.

**Änderung:** Erster Bildschirm: Schlüssel zur Kellertür, erste Kiste zum Abholen, derselbe Tipp löst sichtbar die erste Buchung aus. Dann die drei Erbstücke als wirkliche Wahl, Notarszene freiwillig nachlesen. Die erste bezahlbare Verbesserung soll am geänderten Objekt erscheinen. Gemessen wird vom ersten interaktiven Bild bis zur Buchung bzw. zum **bestätigten** Kauf, für jede Startgabe, nicht bis zur Animation oder zur Shop-Prämie.

### 2 · Kernschleife — **behalten; den Erfolg zurück ins Gebäude holen**

[Ausbau-Vorschau](https://github.com/mrdevn4ever-sys/noir-ledger-ios/blob/17e03c566a22aa95da625b867011fd8f41146ee9/screenshots/de_tour_04_upgrade_preview.png): Für **20** verdoppelt der Wagen seine Kapazität von 1 auf 2; verkauft werden **6 → 10** Kisten/Min., der erwartete Ertrag steigt **30 → 50**. Das ist besser als ein beliebiges „×2“: Der Spieler erkennt, warum sich der Absatz *nicht* verdoppelt. `Flow.forecast`, gemeinsame Flotte, Lagergrenze, echte Buchungen und reversible Aufmerksamkeit sind der Kern. **Nicht** zum reinen Tippzähler umbauen.

Heute muss man die Verbesserung im Fenster verstehen und danach ihren Effekt im Gewimmel wiederfinden. Statt ständig grüner Pfeile: Nach dem Kauf genau den ersten größeren Transport markieren. Erwarteten Ertrag und tatsächlich verbuchten Minutenwert getrennt benennen. Bei der ersten Auftragswahl dieselben 20 Kisten als **100 ruhig** gegen **145 / +20 Aufmerksamkeit** auf einen Blick gegenüberstellen. Im ersten Auftragsbild ist das zweite Angebot nur teilweise sichtbar. Konsequenz und Frist sollen vor der Zusage lesbar sein, nicht erst nach Scrollen durch die erste Karte.

### 3 · Mittelspiel — **Rhythmus und Weg zum Ziel umbauen, Kapitel behalten**

Kapitel 2 erweitert zunächst die Kundschaft für dieselbe Ware. Hafen, Nachtviertel und Oberstadt bringen neue Waren; Clubnacht und Vertrauen verändern, *wann* bzw. *für wen* sich eine Fahrt lohnt. Das sind echte Unterschiede. Im Hafen- und Nacht-Bild sieht man oben aber erneut Straße und Gras. In [Kapitel 6](https://github.com/mrdevn4ever-sys/noir-ledger-ios/blob/17e03c566a22aa95da625b867011fd8f41146ee9/screenshots/de_tour_14_late.png) meldet das Spiel ein Koks-Problem, doch das betreffende Stockwerk liegt außerhalb des Bildes. Der wichtige Unterschied spielt unterhalb des sichtbaren Ausschnitts.

Die Werkstattleitung und der erste **erfüllte** Auftrag liegen beim Werkzeug-Start 3,7 Minuten auseinander. Das beweist keine 3,7 Minuten ohne Handlung: Angebote, Käufe und Fahrten dazwischen werden vom Bot nicht als Freischaltungen protokolliert. Umgekehrt beweist ein neuer Preis oder ein wiederholtes Angebot keine neue Spielentscheidung. Die geforderten maximal 120 s Abstand in den ersten 30 Minuten sind **nicht belegt**.

**Änderung:** Das Kapitelziel dorthin führen lassen, wo es erfüllt wird; bei einer neuen Etage den Umbau am Ort zeigen. Jeder Abschnitt braucht einen neuen Entschluss: Kundschaft wählen, Fracht priorisieren, Clubnacht nutzen, Zuverlässigkeit gegen Soforterlös abwägen. Später Beschaffungsziel *und* Entfernung anzeigen, etwa „Noch zwei Lieferungen bis …“, nur wenn die Prognose belastbar ist. Ein angeheftetes nächstes Ziel muss auch nach dem Scrollen erreichbar sein (`ChapterStrip` liegt heute *im* ScrollView).

### 4 · Langzeitmotivation — **Geschäftsplan neu bauen; Herausforderungen nicht wegwerfen**

Nach sechs Kapiteln gibt es drei freiwillige 15-Minuten-Herausforderungen mit unterschiedlichen Regeln: reduzierte Flotte, anhaltende Aufmerksamkeit, langsamere Produktion. Je drei Ziele; vollständig geschafft je +10 %, insgesamt höchstens +30 %. Das ist ein Endspiel, kein Prestige-System. Im historischen Langzeitmodell endet die Kampagne für „aktiv“ bei Tag 18,8 und für „überwiegend offline“ bei 18,9. Das spricht im Modell für faire Abwesenheit, nicht für nachgewiesene Bindung an Tag 19.

`FlowContent.milestones` kennt elf wirtschaftliche Schwellen bis Stufe 1000. `SceneArt.stage` wechselt die Raumoptik nur bei 10/25/50/100/200. Nach 200 kann eine Zahl wachsen, aber die Silhouette nicht mehr. Keinen Komplettneustart erzwingen: einen freiwilligen Geschäftsplan vorab durchrechnen und klar zeigen, was bleibt, was sich ändert und welche **andere** Strategie er ermöglicht. Als Sammlung würden gestempelte Seiten echter Verträge die Entscheidungen dokumentieren; keine zufälligen Kaufpakete. Erst die zweite Route testen, bevor weitere Stufen oder Grafiken produziert werden.

### 5 · Rückkehr — **Offline-Abrechnung behalten, Tagesanlass umbauen**

[Ein guter Rückkehrbildschirm](https://github.com/mrdevn4ever-sys/noir-ledger-ios/blob/17e03c566a22aa95da625b867011fd8f41146ee9/screenshots/de_tour_17_return.png): nach 5 h stehen **+228 Tsd., 1.800 Lieferungen und „Jetzt sinnvoll: Wagen ausbauen“**. Auszahlung, Begründung und nächste Handlung passen zusammen. Das ist ein gesetztes QA-Profil, keine Ertragsgarantie. Vor der Automatisierung fehlt dieselbe Stärke: Wer ohne Personal geht, hat nicht dieselbe arbeitende Kette. Vor der ersten Pause zeigen, welche Station weiterarbeitet.

Der Tagesumschlag ist eine wiederholbare Abholung (`RewardsView.DailyPanel`), kein Tagesziel. Clubnächte sind echte zyklische Nachfrage, Herausforderungen frei startbar; das sind keine Kalender-Events. Vorschlag: eine freiwillige heutige Buchseite, wählbar aus zwei Aufträgen mit sichtbarem Ertrag und Abschluss. Kein Verlust einer Serie, kein erfundener Countdown, keine Pflichtbenachrichtigung. Prüfen: nach Abholung direkt zur sinnvollen Station; zweites Öffnen zahlt nicht nochmals.

### 6 · Flüssigkeit — **Architektur behalten, Spätspiel-Scrollen als eigene Abnahme behandeln**

[Vergleich auf demselben Runner](https://github.com/mrdevn4ever-sys/noir-ledger-ios/actions/runs/44618111296), `HEAD` = geprüfte Basis, zwei Wiederholungen: spätes Standbild **58,2 / 58,6 fps**, beim Scrollen **49,4 / 50,2 fps**. p95 beim Scrollen **45,6 / 40,0 ms**, schlechtester Frame **173,1 / 146,2 ms**. Das ist ein sichtbares Risiko, auch wenn der XCTest mit seiner Notbremse bei 20 fps grün ist. Kein 120-Hz-Gerätenachweis und kein Mittelwert über sämtliche iPhones.

Lokale Uhren, `TripMotion`, `FloorStage`, `FloorCrew`, `SceneImages`, `sceneAnimating` und Audioladen außerhalb des Hauptthreads erhalten. Noch bekommen u. a. `StreetSection` und `FloorRow` den Gesamtzustand. Dort zuerst Invalidierungen messen, dann auf kleine Eingabewerte begrenzen. Keine globale `TimelineView`. Vor/nach auf derselben Maschine pro Szenario p95 und Hitch-Zeit vergleichen; auf einem älteren unterstützten iPhone und einem echten ProMotion-Gerät wiederholen, nicht aus dem Simulator hochrechnen.

### 7 · Bedienung & Barrierefreiheit — **Leiste und Wegführung umbauen**

Im [deutschen Großschriftbild](https://github.com/mrdevn4ever-sys/noir-ledger-ios/blob/17e03c566a22aa95da625b867011fd8f41146ee9/screenshots/de_tour_18_large_text.png) enden Ziel und Engpass mitten im Text. Die fünf Tab-Titel liegen dicht, **keine belegte Überlagerung**. Der Code deckelt Gebäude und Leiste bei `.xLarge`, den HUD bei `.xxLarge`; Tab-Texte dürfen bis zur halben Schriftgröße schrumpfen. „Passt in die Breite“ ist keine Großschriftlösung. Das Kassenbuch ist oben und unten verlinkt.

Eine feste Handlung am unteren Rand, sekundäre Ziele bei Platzmangel unter „Mehr“; die Alternative muss dieselben Aktionen eröffnen. Bei Accessibility-Größen echte mehrzeilige Zieltexte und zugängliche Stationsliste neben der Szene anbieten. Abnahme: Erstlieferung, Engpass lösen und Rückkehr in DE/EN, größte Textgröße, VoiceOver und reduzierte Bewegung. Ein sichtbarer Accessibility-Identifier prüft keine Vorlesereihenfolge.

### 8 · Optik, Feedback und Sound — **Bildsprache behalten; Lesbarkeit und Akzente umbauen**

- **Optik:** Färbung von Himmel, Fenstern und Werkstätten, Aufzug links und Figurensilhouetten erzählen derselben Nacht. Im späten Grasraum stehen mehrere Köpfe am Regal ineinander. In `FloorCrew` teilen sich die Arbeitenden denselben `shelfX`; `WorkerLoop` verschiebt die Zeit, nicht den Ablageplatz. Unterschiedliche Ablagepunkte und Wege mit getrennten Silhouetten testen, statt neue Arbeiterporträts zu zeichnen. Mit einem kurzen Loop prüfen, nicht nur mit einem günstigen Standbild.
- **Feedback:** Füllstand, fahrender Wagen, Geld und Buchung sind schon gekoppelt. Tipp, Ablehnung, Transport und Meilenstein dürfen nicht gleich wichtig klingen oder leuchten. Den ersten gelungenen Engpass als kurze, lesbare Sequenz inszenieren: volle Kiste → größerer Wagen → höherer Beleg. Bei reduziertem Bewegungseffekt statischer Vorher/Nachher-Beleg; Haptik und Ton respektieren ihre Schalter.
- **Sound:** 65 `.m4a` im Audiobestand; `SoundEngine` nutzt Hintergrundladen, Stimmenpools, Ereignisabstände, getrennte Musik/Effekte und Kapitelwechsel. Das Vorhandensein eines Prestige-Sounds ist kein spielbares Prestige. Beim Kaltstart kann `play` ohne geladenen Pool lautlos zurückkehren. Der Mix wurde **nicht abgehört**, die Haptik nicht gefühlt. Vor Neuproduktion die ersten drei Aktionen, schnelles Wiederholen, Hintergrund/Rückkehr und Stummschaltung auf Hardware prüfen. Nicht die Kriterien „jedes Tippen erkennbar“ und „jeder automatisch erzeugte Tick macht Lärm“ verwechseln.

### 9 · Monetarisierung — **optionales Modell behalten; Darstellung und Versprechen prüfen**

Sieben StoreKit-Produkte: drei dauerhafte/einmalige Angebote, vier feste Gefallen-Pakete. Preis vom Store, Wiederherstellung vorgesehen, keine erkaufte Zufallsziehung als Kern der Angebote. Das ist kein Nachweis, dass echte Käufe, Restore oder Werbeinventar aktuell funktionieren. [Shop im Test](https://github.com/mrdevn4ever-sys/noir-ledger-ios/blob/17e03c566a22aa95da625b867011fd8f41146ee9/screenshots/en_40_shop.png): drei deaktivierte Videokarten dominieren die erste Seite. Die QA schaltet das Werbe-SDK bewusst ab. Daraus lässt sich kein Ausfall im Release ableiten. Zusatznutzen und freie Alternative nebeneinander, nicht drei Sackgassen nacheinander.

Konkreter Textkonflikt: `TESTFLIGHT.md` nennt beim Teilhaber 16 h offline, Flow rechnet bis 12 h frei / 24 h mit Teilhaber. Vor jeder Veröffentlichung Spiel, lokale Produkttexte und tatsächlich hinterlegte Store-Texte abgleichen. Keine Preisänderung auf Grundlage dieser Analyse. Freien Weg, dauerhaften ×2-Kauf und Video-Pfad mit derselben Strategie simulieren; keinen künstlichen Engpass verkaufen.

### 10 · App-Store-Auftritt — **Icon behalten; Screenshot-Erzählung und Texte neu bauen**

[Installiertes Icon](https://github.com/mrdevn4ever-sys/noir-ledger-ios/blob/17e03c566a22aa95da625b867011fd8f41146ee9/screenshots/en_60_home_screen_icon.png): offenes Buch, goldener Schlüssel und rotes Band bleiben im Raster erkennbar. Nicht durch ein generisches Geldbündel ersetzen. `AppStoreBg1…6` sind Marketing-Hintergründe, keine Spiel-Screenshots: sechs PNG-Dateien, **2.060.161 Byte Quelldaten** im Katalog; keine entsprechende Einsparung beim Download behaupten, bevor ein Archivvergleich vorliegt. Später außerhalb des App-Targets erhalten, nicht ersatzlos löschen.

Kein belegter aktueller Storefront-Satz, keine Conversion-Zahlen. Für DE/EN mit echten Builds erzählen: **(1)** ein Keller/ein Auftrag, **(2)** der entscheidende Wagenkauf samt ehrlichem Vorher/Nachher, **(3)** der gewachsene Querschnitt, **(4)** der Konflikt zwischen ruhigem und auffälligem Auftrag, **(5)** die Abrechnung der letzten Nacht. Keine inszenierte Funktion, die im Spiel fehlt. Textprobe für die Positionierung: „Alles Legale ist schon verkauft. Dir bleiben ein Keller, ein Kassenbuch und eine sehr ungeduldige Stadt.“ / “Everything legal has already been sold. You inherit a cellar, a ledger, and a very impatient city.”

Gras, Crystal, Pillen und Koks bleiben Teil einer Satire über Buchführung und ihre Folgen. Weder Herstellung noch Konsum erklären oder bewerben. Für den Eigentümer: Fragebogen wahrheitsgemäß, höchste einschlägige Einstufung anstreben; eine Altersangabe ist kein Ersatz für [Review-Regel 1.4.3](https://developer.apple.com/app-store/review/guidelines/#physical-harm). Store-Bildsprache mit Schlüssel, Firmenpleiten und Buchungen statt Konsummotiven. Keine Änderung in App Store Connect.

## Was der Genrevergleich ändert

- [Idle Miner Tycoon · Produktionskette](https://idleminertycoon.fandom.com/wiki/Fundamental_Gameplay): Der Reiz liegt im Wechsel des Engpasses zwischen Herstellung und Transport. NOIR LEDGER hat diesen Effekt schon; der nächste Kauf muss **in der Szene** zeigen, was die Zahlen gerade erklärt haben. Nicht dessen Figuren oder Oberfläche nachbauen.
- [Egg, Inc. · Prestige](https://egg-inc.fandom.com/wiki/Prestige): Ein langsamer Abschnitt bekommt Bedeutung, wenn der nächste Durchlauf einen sichtbar anderen Ertrag verspricht. Für Varnholm sollte der Plan eine andere Betriebsweise eröffnen, nicht nur denselben Keller schneller wiederholen. Das sind Mechanikvergleiche, keine gemessenen Konkurrenzzeiten und kein Ranking.

## Grenze vor dem Umbau

1. **Zuerst testen:** erstes interaktives Bild → erste selbst ausgelöste Belohnung ≤5 s → erster bestätigter Ausbau ≤20 s. Jede Startgabe getrennt; keine Tagesprämie, kein Shop, keine vorgespulte Uhr. Erst der Test mit neuen Spielern beantwortet, ob sie *weiterspielen wollen*.
2. **Dann den Rhythmus messen:** über die ersten 30 Minuten alle neuen Entscheidungen und sichtbaren Veränderungen mit Zeitstempel erfassen; maximale Lücke ≤120 s. Wiederholter identischer Kauf zählt nicht. Am Sitzungsende ohne Anleitung erfragen: „Was hat sich sichtbar verändert?“ und „Was würdest du als Nächstes tun?“ Keine erfundene Wow- oder Retentionsquote.
3. **Vor Änderung von Ökonomie oder Schema:** ausführbare Python-Baseline und Vergleich der drei Starts plus aktiv/offline/unausgewogen gegen den echten Swift-Kern. `FlowSaveStore` schreibt `noir_flow.save` samt Backup; das in `SAVE_FORMAT.md` beschriebene `noir_ledger.save` gehört zur Altfassung. Alte Wallet-Übernahme ist keine Migration des aktuellen Fortschritts. Versionsgebundene TestFlight-Fixtures mit Kapitel, Bargeld, Personal, Aufträgen, Gefallen, Entitlements und Offline-Zeit zweimal laden; kein Reset oder doppelter Ertrag. Der Geschäftsplan bleibt freiwillig.

Kein Gameplay-, Preis-, Asset- oder Save-Umbau in diesem Audit. Kein TestFlight-Build und keine Einreichung für diesen Diagnoseschritt.
