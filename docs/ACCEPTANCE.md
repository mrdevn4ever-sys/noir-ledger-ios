# Acceptance

Hash-bound acceptance record for NOIR LEDGER iOS 1.0 (1).

| Binding | Value |
| --- | --- |
| Accepted code commit | `aed8f35e0c670e688a47fde75a5ab585e09d613a` |
| CI run | [42458444443](https://github.com/mrdevn4ever-sys/noir-ledger-ios/actions/runs/42458444443), attempt 1, conclusion `success` |
| Evidence | branch `evidence/run-42458444443-1` (`acceptance-report.md`, `.json`, logs, 88 screenshots, Release app zip, contact sheet) |
| Runner | GitHub `macos-15` image 20261104.0514.1, macOS 15.8.2, Xcode 16.4 (16F6), Swift 6.1.2 |
| Simulator | iPhone 17, iOS 26.2 (23C54) |
| Android canonical source | `F:/Projects/NoirLedger` at `438e316c06ede34a04b0b90f058cbbdd3cb1ced3` (read-only) |
| `shared-assets/manifest.json` SHA-256 | `9018da2f4825ef40d9ca9cd813fa01776c06ebbbd2026d928c34a7899c941636` |

Every commit after `aed8f35` changes files under `docs/` only. The trees `App`, `Packages`, `AppTests`, `UITests`,
`scripts`, `.github`, `project.yml` and `shared-assets` are byte-identical to `aed8f35` (same git tree hashes), so
the build inputs proven by run 42458444443 are unchanged. The CI rerun dispatched for the first docs commit `5081b1c`
(run 42460957805) did not start any job: GitHub refused the macOS runners because the account's Actions spending
limit or payment needs attention. Paid overage is not authorized, so that rerun is outstanding until the owner's
Actions minutes are available again.

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| Core engine (`swift test`, macOS host) | 97/97 passed | `core-tests.log` |
| Deterministic playthroughs | seed 1 won in 10.63 h, seed 42 in 10.53 h, seed 2024 in 10.86 h; New Game+ won in 10.46 h | `core-tests.log`, `acceptance-report.md` |
| Xcode tests (app + UI, simulator) | 31/31 passed, 0 failed, 0 skipped (16 Swift Testing app tests, 15 XCTest UI tests) | `test-summary.json`, `tests.json`, `xcodebuild-test.log` |
| Localization parity | `L10N_OK`: 573 English and 573 German keys, 269 literal keys used, 6 plural keys | `l10n.log` |
| Shared-asset parity and tokens | `ASSET_PARITY_OK`: 51 manifest assets, 51 iOS exports, 49 imagesets, 22 tokens identical to `Theme.swift` | `asset-parity.log` |
| Source scan (no unfinished markers, real drug terms, network/billing/ads/analytics/tracking APIs or secrets) | `SCAN_OK` | `scan.log` |
| Release simulator build | succeeded; app zip 3,274,971 bytes | `xcodebuild-release.log`, `NoirLedger-Release-iphonesimulator.app.zip` |
| QA accelerator excluded from Release | `RELEASE_EXCLUSION_OK`: all 7 markers found 0 times in the 7,334,168-byte Release binary | `release-exclusion.log` |
| Screenshots | 88 captured from the running app (EN and DE tours, flows, states, large text, installed icon) | `screenshots/`, `inventory.txt` |
| Canonical contact sheet | rendered from `shared-assets/` on the runner | `shared-assets-contact-sheet.png` |
| Cross-platform byte parity | PASS: 76/76 files identical, none missing or extra, matching manifest SHA-256 | Android `tools/assets/compare_parity.py`, run read-only with `python -I -B` |
| Side-by-side parity sheet | PASS after inspection | [parity/android-ios-parity-sheet.jpg](parity/android-ios-parity-sheet.jpg) |
| Visual QA | two bounded passes, all release-blocking findings fixed and re-captured | see below |

## Tests

App tests (Swift Testing, hosted in the app):
- **Localization integrity:** identical key sets, every content-derived label in both languages, every journal kind, number, money and duration formats per language, and effect lines.
- **Game store:**
  - a fresh install starts at the prologue and writes a save;
  - actions persist across relaunch, and time away is credited with a summary;
  - a rejected action leaves the state untouched;
  - a damaged save is recovered from the backup;
  - a save from a newer version is protected;
  - reset erases legacy and campaign;
  - online ticks run the simulation in real time.
- **Settings:** the language choice persists.
- **Shared asset inventory:** every referenced asset is compiled, and the 12 portraits, 5 districts and 4 product seals are present.
- **QA accelerator boundary:** the accelerator is present in Debug only.

UI tests (XCTest):
- **Fresh install:** prologue and the seven-step briefing.
- **Core systems through the UI:** lines, stash, routes, fronts, Heat actions, hiring, dismissal and rehiring, improvements, legacy.
- **Persistence:** relaunch with an offline return summary.
- **Investigation:**
  - countermeasures in real time;
  - an unanswered investigation leads to a raid and then recovery.
- **Final operation:** epilogue, legacy perk and New Game+.
- **Language:** manual switch and system German detection.
- **Large Dynamic Type.**
- **Reset confirmation.**
- **Saves:** damaged-save recovery and protection of a save from a newer version.
- **Installed home-screen icon.**
- **Screenshot tours:** full English and German tours.

## Visual QA

**Pass 1** (run 8 evidence, `204761a`). Nine findings, all fixed:
- district banner overflow;
- a doubled "/min";
- the alert-strip action word;
- "Locked" instead of "Move in" on reachable districts;
- the epilogue time;
- the perk plural;
- header stacking at accessibility sizes;
- the HUD Dynamic Type cap;
- a duplicate Settings label.

All nine fixes were confirmed in later captures.

**Pass 2** (run 10 evidence at `c0ce424`, all 88 screenshots, then the fresh run 42458444443 captures at `aed8f35`):
- **One release-blocking finding.** In the German final-operation requirements, "(88 %)" wrapped so that the % sign
  stood alone on the next line. Fixed in `aed8f35`: every German percentage (the shared `percent` format and 22
  improvement/perk descriptions) now uses U+00A0 NO-BREAK SPACE, and the exact-format app tests assert it. The fresh
  `de_tour_24_final_requirements.png` shows "70 %" and "(88 %)" each kept on one line.
- **Re-reviewed on the fresh captures:**
  - all 31 German screens;
  - every English capture that changed by more than 0.5% of pixels against run 10 (the others differ only in clock and live values);
  - 1.3× text in both languages;
  - all five district cards and the North Quay detail;
  - the final operation requirements and phase;
  - the epilogue with books and credits;
  - the active New Game+ ledger.
- **No further release-blocking findings.** Recorded observations, not defects:
  - some captures catch a button mid-press or a 200 ms prologue page fade (capture timing);
  - at 1.3× text, German "Kontrolle" and "erreichen" hyphenate in the narrow objective column, which stays readable and correct;
  - QA scenarios show a "0 s" time in the city or fractional seized units where the scenario state truly has them.

## Asset parity

`shared-assets/` is a byte-identical copy of the Android canonical pack at `438e316`, which includes the final district
contrast masters. iOS exports are generated from those masters by `scripts/shared_assets.py export`. On every CI run,
`scripts/shared_assets.py check` verifies:
- manifest hashes;
- that no file is missing from the manifest;
- byte-identical iOS exports;
- that every asset name used in Swift exists;
- the 22 shared colour tokens.

Branded marks are never SF Symbols.

`scripts/qa/parity_sheet.py` composes real runtime captures side by side, with no redrawn art: the Android lane's
`.qa/final` captures next to this run's iOS captures, plus both canonical contact sheets. Inspected rows:

| Row | Android | iOS | Result |
| --- | --- | --- | --- |
| Installed app icon | `98_launcher_icon` | `en_60_home_screen_icon` | same leather-ledger icon; only the platform mask differs |
| City and district motifs | `10/11/12_city_*` | `en_tour_08/09/10` | all five district illustrations identical and legible on dark cards |
| District detail (North Quay) | `22_district_docks` | `en_tour_11_district` | same crane banner |
| New Game+ ledger | `40_ng_ledger_top` | `en_tour_28_new_game_plus` | same chapter 1 objectives and NG+ level |
| Canonical contact sheets | `docs/asset-contact-sheet.png` | CI `shared-assets-contact-sheet.png` | same 51 assets |

The layouts differ by design (native Material vs native iOS chrome). The tokens, marks, illustrations, portraits and
icon are shared.

## Limitations and notes

- **Artifact storage:** the GitHub account's artifact storage quota is exhausted by other repositories, so
  `actions/upload-artifact` reports a quota error (the step is `continue-on-error`). The workflow pushes the identical
  evidence to an `evidence/run-<id>-<attempt>` branch of this private repository instead.
- **Playthrough bot:** the deterministic bot meets fewer investigations than the reference text suggests (0–1 per
  campaign). The tests therefore assert peak Heat ≥ 50 rather than an investigation count. Investigations, raids and
  recovery are covered directly by core tests and UI tests.
- **Signing and distribution:** none of code signing, TestFlight, App Store Connect or publication is in scope or
  authorized. The Release build is a simulator build.
- **Android checkout:** at the time of this record the Android checkout contained an untracked file that the iOS lane did not create,
  `docs/asset-contact-sheet-preview.png` (created 2026-11-08 07:57 +01:00). It lies outside `shared-assets/` and was
  left untouched.
