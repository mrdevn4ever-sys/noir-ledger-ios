# NOIR LEDGER iOS — verbindlicher Spielauftrag

## Produktentscheidung

- **Titel:** NOIR LEDGER
- **Genre:** tiefes Offline-Idle-Tycoon-/Management-Spiel
- **Plattform:** iPhone / iOS
- **Technik:** native Swift- und SwiftUI-Architektur; kein Flutter, React Native, WebView-Spiel oder geteilter Cross-Platform-UI-Code
- **Ausrichtung:** Hochformat, Smartphone-first, iPhone-only sofern kein zwingender Grund für Universal besteht
- **Bundle-ID:** `io.puredevn.noirledger`
- **Zielgruppe:** Erwachsene; düstere, möglichst glaubwürdige Crime-Noir-Welt
- **Geschäftsmodell:** bezahlte Premium-App als Einmalkauf im App Store; keine Werbung, keine In-App-Käufe, kein Abo und daher kein StoreKit-Paywall-System
- **Auslieferung in diesem Auftrag:** vollständiger Quellcode, erfolgreich kompilierter iOS-Simulator-Build, grüne native Tests, UI-Tests und echte Simulator-Screenshots als GitHub-Actions-Artefakte. Keine Codesignierung, kein TestFlight-/App-Store-Upload und keine App-Store-Connect-Änderung.
- **Private Buildstrecke:** `mrdevn4ever-sys/noir-ledger-ios`; der Eigentümer hat Quellcode-Upload in ein privates GitHub-Repository und mögliche GitHub-Actions-macOS-Minuten ausdrücklich autorisiert.

## Paritätsauftrag

Dies ist die native iOS-Fassung desselben Spiels wie die Android-Version. `docs/reference-game-rules.md` ist der konkrete Inhalts-, Balancing- und Systemvertrag. Alle dort aufgeführten Bezirke, fiktiven Produktlinien, Ressourcen, Frontbetriebe, Crew-Rollen, Verbesserungszweige, Ereignisse, Kapitelziele, Finaloperationen, Epilog, Legacy-Punkte, New-Game+-Regeln und Offline-Regeln müssen semantisch identisch umgesetzt werden. Plattformgerechte Navigation und Darstellung dürfen abweichen; Spielregeln und Resultate nicht.

Die Referenz stammt aus Android-Commit `8a631ba5c1be5d01415f34c983716ccf6b203806`. Wenn Quelltext und Referenzdokument widersprechen, gewinnt dieser iOS-Auftrag zusammen mit `docs/reference-game-rules.md`; Abweichungen müssen ausdrücklich dokumentiert und dürfen nicht still erfunden werden.

## Unverhandelbarer Fertigstellungsstandard

Das Ergebnis ist kein Prototyp, keine Beta, kein Vertical Slice, keine Technikdemo und keine Roadmap. Es muss vom ersten Start bis New Game+ spielbar sein. Keine Platzhaltergrafiken, TODO/FIXME-Kommentare, toten Schaltflächen, „Coming soon“-Bereiche, nur vorbereiteten Tests oder vorgetäuschten Systeme. Eine Funktion gilt nur als vorhanden, wenn sie funktioniert, gespeichert wird, im Kampagnenfluss erreichbar ist und auf einem echten iOS-Simulator-Build geprüft wurde.

Die Windows-Quelle allein ist kein Fertigstellungsnachweis. Parser-Checks, Textsuche oder ein erzeugtes Xcode-Projekt ersetzen weder Apple-SDK-Kompilierung noch native Swift-/UI-Tests. „Fertig“ verlangt grüne Xcode-Gates und visuelle Simulator-Evidenz auf einem GitHub-gehosteten macOS-Runner.

## Inhaltliche Leitplanken

Die Welt behandelt ein **fiktives Drogenimperium**. Alle Substanzen, Organisationen, Figuren, Orte und Marken sind erfunden. Keine echten Herstellungsrezepte, Dosierungen, Beschaffungswege oder praktisch nutzbaren Anleitungen für reale Straftaten; keine explizite Konsumdarstellung, kein Gore und keine sexualisierte Gewalt. Der Ton ist erwachsen, ernst und angespannt, mit höchstens trockenem schwarzem Humor — nicht comicartig und nicht verherrlichend.

## Vollständiger Spielbogen und Systeme

Der Spieler beginnt mit einem Kellerbetrieb in Varnholm und beendet die Kampagne mit der Kontrolle über den gesamten Untergrund. Verbindlich enthalten:

1. interaktiver Prolog mit echter Startentscheidung,
2. siebenstufiges, durch tatsächliche Aktionen gespieltes Tutorial,
3. klarer Früh-, Mittel- und Spätspielfortschritt über sechs Kapitel,
4. fünf mechanisch und visuell unterscheidbare Stadtbezirke,
5. vier vollständig fiktive Produktlinien mit unterschiedlichen Wirtschaftsprofilen,
6. Produktion, Lager, Vertrieb/Routen, schmutziges Geld, sauberes Geld und Einfluss,
7. fünf Geldwäsche-Frontbetriebe, Reserve- und Schutzsysteme,
8. Heat, sichtbare Warnung, Ermittlungs-Countdown, Gegenmaßnahmen, faire Razzia und garantierte Erholbarkeit,
9. zwölf benannte Crew-Kandidaten in sechs Rollen mit Eigenschaften, Lohn und Loyalität,
10. fünf Verbesserungszweige mit echten Tier-2-Entscheidungen,
11. fünfzehn verfasste Risiko-Ertrag-Ereignisse,
12. Kapitelmissionen, Finaloperation mit drei Phasen, echte Siegbedingung,
13. Epilog, Statistiken/Abspann und startbares New Game+ mit Legacy-Punkten und permanenten Vorteilen,
14. Offline-Fortschritt bis acht Stunden, verständliche Rückkehrzusammenfassung und Schutz gegen rückwärts/absurd verstellte Uhren,
15. atomarer, versionierter lokaler Spielstand mit Backup/Migration, automatischem Speichern, Zurücksetzen mit Bestätigung und Wiederherstellung nach Prozessabbruch.

Alle Zahlen, Formeln und Balancing-Verträge stehen in `docs/reference-game-rules.md`.

## Native iOS UX und Art Direction

- Düstere, realistische Neon-Noir-Art-Direction: Schwarz/Anthrazit, gealtertes Leder/Papier als Akzent, schmutziges Bernstein/Altgold für Wert und kontrolliertes Rot nur für Heat/Gefahr.
- Das Geschäftsbuch ist das Leitmotiv. Stadt, Betriebe und Buchhaltung sind visuell klar getrennt.
- Keine generische SwiftUI-Demo, kein Web-Dashboard-Look, keine Emoji-Icons, keine zufälligen Standardkarten, keine überladene Poster-Montage hinter spielrelevanten Informationen.
- Native SwiftUI-Navigation, Safe Areas, System-Back/Swipe-Gesten, eindeutige Hierarchie und einhändige Erreichbarkeit.
- Mindestens 44×44 pt große Touch-Ziele; klare tabellarische Zahlen; ausreichender Kontrast trotz dunkler Stimmung.
- Dynamic Type ohne abgeschnittene Kerninhalte, VoiceOver-Bezeichnungen und sinnvolle Lesereihenfolge, Bold Text/Increase Contrast soweit sinnvoll, Reduce Motion und Differentiate Without Color.
- Zweckvolle, kurze Animationen und Press-Feedback; keine langsame oder dekorativ überladene Daueranimation.
- Alle Zustände gestaltet: Erststart, Tutorial, Hauptspiel, leer, gesperrt, nicht bezahlbar, Erfolg, Warnung, Ermittlung, Razzia, Offline-Rückkehr, Fehler/Save-Recovery, Kampagnenende und New Game+.
- Vollständige deutsche und englische Lokalisierung mit Systemsprachenerkennung und manueller Sprachwahl; keine hart codierten spielerlesbaren Strings.
- Eigene SwiftUI-/CoreGraphics-/SF-Symbol-basierte, lizenzkonforme Grafik. Das Moodboard ist nur Richtungsreferenz, kein direkt übernommener Gameplay-Hintergrund.
- Liquid Glass ist kein Selbstzweck. Es darf nur genutzt werden, wenn es die festgelegte Noir-Materialität und Lesbarkeit unterstützt und die gewählte Mindestversion nicht unnötig erhöht; ansonsten ausdrücklich begründet ausschließen.

## Visuelle Referenz

`docs/noir-ledger-moodboard.png`

Zu übernehmen: glaubwürdige europäische Nachtstadt, gealterte Materialien, warme Geschäftsräume, gezielte rote Warnakzente, Geschäftsbuch als Leitmotiv und visuelle Trennung zwischen Stadt, Betrieben und Buchhaltung.

Nicht zu übernehmen: überladene Poster-Montage als Gameplay-Hintergrund, zu dunkle Informationsflächen, unlesbare Kleindetails, echte Marken oder explizite Substanzdarstellung.

## Technische Anforderungen

- Native Swift/SwiftUI-App mit sauberer Trennung zwischen deterministischer Simulation, Persistenz und UI.
- Kernsimulation muss ohne SwiftUI und ohne laufenden Simulator vollständig unit-testbar sein.
- Moderne, vom eingesetzten Xcode unterstützte Swift-Sprachversion; Warnungen im CI sichtbar und keine bewusst ignorierten Compilerfehler.
- Mindest-iOS-Version bewusst festlegen und begründen. Keine Verwendung nicht verfügbarer APIs ohne saubere Availability-Grenze.
- Lokale Offline-App: kein Konto, Backend, Tracking, Analytics, Attribution, Werbung oder Netzwerkfeature. Keine Drittanbieter-SDKs ohne zwingenden Grund.
- Keine geheimen Schlüssel, Zertifikate, Provisioning Profiles oder Apple-Credentials. Simulator- und Test-Builds müssen ohne Codesigning laufen.
- Reproduzierbares Projekt. Eine Project-Generator-Lösung wie XcodeGen ist erlaubt, wenn Konfiguration und Generierung vollständig im Repository liegen und CI sie tatsächlich ausführt.
- GitHub Actions muss auf einem macOS-Runner Xcode-Version, Simulator-Ziel und Build-Provenienz protokollieren, Projekt generieren/auflösen, kompilieren, Unit- und UI-Tests ausführen, Screenshots sowie Simulator-`.app`/Testergebnisse als Artefakte hochladen.
- Debug/Test-Builds dürfen einen klar getrennten, nicht in Release kompilierten Kampagnenbeschleuniger für End-to-End-QA besitzen. Keine Debug-Steuerung in der normalen Spieleroberfläche oder Release-Konfiguration.
- Repository enthält korrekte Build-/Test-/Spielanweisungen, Architektur, Regeln, Save-Schema/Migration und die QA-Beschleuniger-Dokumentation. Keine Roadmap als Ersatz für fehlende Funktionen.

## Verbindliche Qualitäts- und Abnahmegates

Claude Code muss die realen Befehle/Workflows ausführen, CI-Ergebnisse lesen und Fehler bis zu grünen Gates beheben:

1. Privates GitHub-Repository korrekt gebunden, keine versehentlichen öffentlichen Inhalte.
2. Projektgenerierung/Dependency-Auflösung auf macOS erfolgreich.
3. Vollständiger Apple-SDK-Compile/Simulator-Build erfolgreich; keine bloße Swift-Parser-Prüfung.
4. Unit-Tests für Ökonomie, Produktion, Vertrieb, Geldwäsche, Heat/Ermittlungen/Razzien, Crew/Loyalität, Ereignisse, Verbesserungen, Kapitel, Offline-Zeit, Save-Codec/Migration, Kampagnenende und New Game+.
5. Deterministische vollständige Kampagnen-Playthroughs über mehrere Seeds und ein New-Game+-Durchlauf innerhalb vernünftiger Balancing-Grenzen.
6. XCUITest-/SwiftUI-UI-Tests für Erststart/Tutorial, Navigation, Persistenz nach Relaunch, Sprachen, Finaloperation, Epilog und New Game+.
7. Echte iOS-Simulator-App auf dem GitHub-macOS-Runner starten und den vollständigen Spielfluss mit Debug-Beschleuniger ausüben.
8. Deutsche und englische UI sowie repräsentative große Dynamic-Type-Stufe prüfen.
9. Screenshots aller Hauptzustände als CI-Artefakte aufnehmen und in höchstens zwei gebündelten visuellen QA-Pässen bewerten/korrigieren.
10. Keine Crashes, Hänger, abgeschnittenen Kerninhalte, unauflösbaren Zustände, fehlenden Accessibility Labels oder sichtbaren Entwicklerartefakte.
11. Abschlussscan: keine TODO/FIXME/Platzhalter/Coming-soon-Texte, keine echte Drogenterminologie, kein Netzwerk-/Ads-/Billing-/Analytics-/Tracking-Code, keine unlokalisierten spielerlesbaren Strings.
12. Nach letzter Korrektur alle Build-/Test-/UI-Gates erneut auf dem exakten finalen Commit ausführen; erfolgreicher früherer Run zählt nicht als finale Evidenz.

## Definition von „fertig“

Fertig ist die iOS-Version erst, wenn ein neuer Spieler ohne Entwicklerhilfe das Tutorial abschließen, die vollständige Kampagne gewinnen, den Epilog sehen und New Game+ starten kann; der Spielstand App-Neustarts überlebt; Offline-Fortschritt korrekt funktioniert; Deutsch und Englisch vollständig sind; alle genannten Systeme tatsächlich zusammenspielen; das finale Commit auf einem macOS-GitHub-Runner kompiliert; Unit- und UI-Tests grün sind; der Simulator-Build funktional geprüft wurde; und die finalen Screenshots die visuelle sowie barrierearme Abnahme bestehen.
