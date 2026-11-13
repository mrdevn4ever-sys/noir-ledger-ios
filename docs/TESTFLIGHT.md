# Auftrag an Hermes: NOIR LEDGER auf TestFlight bringen

Ziel: Die App liegt als Build in App Store Connect und ist über TestFlight (interne Tester) auf dem iPhone des
Eigentümers installierbar. Du arbeitest auf dem Windows-PC des Eigentümers. Gebaut, signiert und hochgeladen wird
**nicht** auf dem PC, sondern auf einem GitHub-macOS-Runner durch `.github/workflows/testflight.yml`. Deine Aufgabe ist
die Apple-Seite, die GitHub-Secrets und das Anstoßen des Uploads.

- Repository: `mrdevn4ever-sys/noir-ledger-ios` (öffentlich), Branch `claude/exciting-cori-5r0kcv`
- Bundle-ID: `io.puredevn.noirledger` · Version 1.0 · Build-Nummer setzt der Workflow selbst

## 0. Sicherheitsregeln (gelten für alles)

1. **Niemals** Schlüssel, Zertifikate, Passwörter oder Profile committen, in den Chat schreiben oder in Logs ausgeben.
   Das Repository ist öffentlich. Alles Geheime liegt nur in `%USERPROFILE%\.noir-signing\` und in GitHub-Secrets.
2. **Nichts löschen oder widerrufen**, was schon existiert: keine Zertifikate, Profile, Apps, Bundle-IDs, Produkte.
   Stößt du an ein Limit, hör auf und frag.
3. Keine Verträge, Steuer- oder Bankangaben im Namen des Eigentümers bestätigen. Das macht er selbst.
4. Nichts zur App-Prüfung (App Review) einreichen, keine externen Tester, keine öffentlichen Links.
5. Swift-Code und Workflow-Dateien änderst du nicht. Scheitert der Build, meldest du die Fehlerzeilen.

## 1. Voraussetzungen prüfen (bei Fehlen: stoppen und den Eigentümer fragen)

- Bezahlte Mitgliedschaft im Apple Developer Program ist aktiv.
- In App Store Connect unter **Business** ist der Vertrag **Paid Apps** aktiv (inkl. Steuer und Bank). Ohne ihn
  funktionieren In-App-Käufe nicht einmal im Test. Fehlt er, sag dem Eigentümer genau, wo er ihn abschließt, und
  mach mit allem anderen weiter.
- Auf dem PC: Python 3 mit `pyjwt`, `cryptography`, `requests`; GitHub CLI `gh` angemeldet mit Schreibrecht auf das
  Repository; `git`.

## 2. App-Store-Connect-API-Schlüssel

Im angemeldeten Browser: App Store Connect → **Benutzer und Zugriff → Integrationen → App Store Connect API →
Teamschlüssel** → neuen Schlüssel „NOIR LEDGER CI“ mit Rolle **Admin** anlegen. Notiere Issuer-ID und Key-ID, lade
die `.p8` herunter (geht nur einmal) und lege sie nach `%USERPROFILE%\.noir-signing\`.
Kannst du den Browser nicht steuern oder fehlt die Berechtigung: stoppen, der Eigentümer legt ihn an.

Alle weiteren Schritte laufen über die API (`https://api.appstoreconnect.apple.com`, JWT mit ES256, `kid` = Key-ID,
`iss` = Issuer-ID, `aud` = `appstoreconnect-v1`, Laufzeit höchstens 20 Minuten).

## 3. Bundle-ID, Zertifikat, Profil

1. **Bundle-ID:** `GET /v1/bundleIds?filter[identifier]=io.puredevn.noirledger`. Fehlt sie:
   `POST /v1/bundleIds` mit `identifier`, `name` „NOIR LEDGER“, `platform` „IOS“. Keine weiteren Capabilities
   (In-App-Käufe sind standardmäßig an; Mitteilungen sind lokal und brauchen keine).
2. **Distribution-Zertifikat:** RSA-2048-Schlüssel und CSR mit `cryptography` erzeugen,
   `POST /v1/certificates` mit `certificateType` „DISTRIBUTION“. Meldet Apple ein Limit: stoppen, vorhandene
   Zertifikate auflisten, Eigentümer fragen.
3. **.p12 bauen** aus Schlüssel und Zertifikat, mit zufälligem Passwort. **Wichtig:** macOS liest nur das alte
   Verschlüsselungsformat. Verwende in `cryptography`:
   `PrivateFormat.PKCS12.encryption_builder().kdf_rounds(50000).key_cert_algorithm(pkcs12.PBES.PBESv1SHA1And3KeyTripleDESCBC).hmac_hash(hashes.SHA1()).build(passwort)`
4. **Profil:** `POST /v1/profiles` mit `name` „NOIR LEDGER App Store“, `profileType` „IOS_APP_STORE“, Beziehungen
   zur Bundle-ID und zum neuen Zertifikat. `profileContent` (Base64) speichern.
5. **Team-ID:** steht im Profil (eingebettete XML-Plist, Schlüssel `TeamIdentifier`).

## 4. App-Eintrag in App Store Connect

`GET /v1/apps?filter[bundleId]=io.puredevn.noirledger`. Fehlt die App, lege sie an. Wenn die API das Anlegen nicht
erlaubt, im Browser: **Apps → + → Neue App**:

| Feld | Wert |
| --- | --- |
| Plattform | iOS |
| Name | `NOIR LEDGER` (vergeben? dann `Noir Ledger: Idle Empire`, dann `Noir Ledger – Crime Tycoon`) |
| Primäre Sprache | Deutsch |
| Bundle-ID | `io.puredevn.noirledger` |
| SKU | `noirledger-ios` |
| Benutzerzugriff | Vollzugriff |

Geht beides nicht: stoppen und dem Eigentümer genau diese Tabelle schicken.

## 5. In-App-Käufe (sieben Produkte)

Die Produkt-IDs müssen exakt stimmen, der Code findet sie nur darüber.

| Produkt-ID | Typ | Name DE / EN | Preis |
| --- | --- | --- | --- |
| `io.puredevn.noirledger.starter` | Nicht-Verbrauchsartikel | Starterkiste / Starter crate | 3,99 € |
| `io.puredevn.noirledger.premium2x` | Nicht-Verbrauchsartikel | Stiller Teilhaber / Silent partner | 6,99 € |
| `io.puredevn.noirledger.noads` | Nicht-Verbrauchsartikel | Keine Videos / No videos | 4,99 € |
| `io.puredevn.noirledger.favors.small` | Verbrauchsartikel | Eine Handvoll Gefallen / A handful of favors | 0,99 € |
| `io.puredevn.noirledger.favors.medium` | Verbrauchsartikel | Eine Schublade Gefallen / A drawer of favors | 4,99 € |
| `io.puredevn.noirledger.favors.large` | Verbrauchsartikel | Ein Tresor Gefallen / A safe of favors | 9,99 € |
| `io.puredevn.noirledger.favors.vault` | Verbrauchsartikel | Das Gewölbe / The vault | 19,99 € |

Beschreibungen (DE / EN):

- starter: „200 Gefallen und 4 Stunden doppelter Ertrag. Einmalig.“ / „200 favors and a 4 hour ×2 boost. Once.“
- premium2x: „Jeder Ertrag dauerhaft verdoppelt, 16 Stunden Offline-Zeit.“ / „Every payout doubled for good, 16 hours offline.“
- noads: „Alle Sponsorenbelohnungen ohne Video.“ / „Every sponsor reward without a video.“
- favors.*: „80 / 500 / 1.200 / 3.000 Gefallen“ / „80 / 500 / 1,200 / 3,000 favors“

Je Produkt per API: anlegen (`/v2/inAppPurchases`), Lokalisierungen `de-DE` und `en-US`, Preisplan mit Basisgebiet
Deutschland und dem passenden Preispunkt, Verfügbarkeit in allen Gebieten. Prüfungs-Screenshot: vorerst
`screenshots/de_tour_06_operations.png` aus dem Branch `evidence/run-43462844075-1` (vor einer echten App-Prüfung
durch einen Shop-Screenshot ersetzen). Ziel ist Status „Bereit zur Einreichung“.
Hakt ein Produkt: überspringen und melden. Der TestFlight-Upload hängt nicht davon ab.

## 6. GitHub-Secrets setzen

Werte nie als Kommandozeilenargument übergeben, sondern über die Standardeingabe:
`python gib_wert.py | gh secret set NAME -R mrdevn4ever-sys/noir-ledger-ios`. Base64 jeweils einzeilig.

| Secret | Inhalt |
| --- | --- |
| `ASC_KEY_ID` | Key-ID des API-Schlüssels |
| `ASC_ISSUER_ID` | Issuer-ID |
| `ASC_KEY_P8_BASE64` | die `.p8`-Datei, Base64 |
| `APPLE_TEAM_ID` | Team-ID (10 Zeichen) |
| `DIST_CERT_P12_BASE64` | die `.p12` aus Schritt 3, Base64 |
| `DIST_CERT_PASSWORD` | Passwort der `.p12` |
| `APPSTORE_PROFILE_BASE64` | das Profil (`profileContent`, ist schon Base64) |

## 7. Upload anstoßen und beobachten

```
git fetch origin claude/exciting-cori-5r0kcv
git tag testflight-1 origin/claude/exciting-cori-5r0kcv
git push origin testflight-1
gh run watch -R mrdevn4ever-sys/noir-ledger-ios
```

Weitere Uploads später mit `testflight-2`, `testflight-3` … (jeder Tag einmal).

- **Rot:** `gh run view <id> --log-failed -R mrdevn4ever-sys/noir-ledger-ios`. Ist es ein Apple-Problem
  (Zertifikat, Profil, fehlendes Secret, App-Eintrag): beheben und mit neuem Tag erneut. Ist es ein Code- oder
  Build-Fehler: die Fehlerzeilen melden, nichts am Code ändern.
- **Grün:** Apple verarbeitet den Build 10–30 Minuten. Danach in TestFlight eine interne Gruppe „Intern“ anlegen,
  den Eigentümer als Tester hinzufügen und den Build der Gruppe zuweisen. Die Exportfrage zur Verschlüsselung ist
  über die Info.plist bereits beantwortet.

## 8. Abschlussmeldung

- Build-Nummer und Status in TestFlight
- welche der sieben Produkte „Bereit zur Einreichung“ sind
- ob der Vertrag „Paid Apps“ aktiv ist
- was der Eigentümer selbst noch tun muss
- Bestätigung: keine Geheimnisse im Repository, nichts gelöscht oder widerrufen
