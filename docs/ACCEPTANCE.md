# Acceptance

Hash-bound acceptance record for NOIR LEDGER iOS 1.0 (1).

| Binding | Value |
| --- | --- |
| Accepted code commit | `aed8f35e0c670e688a47fde75a5ab585e09d613a` |
| CI run | [42458444443](https://github.com/mrdevn4ever-sys/noir-ledger-ios/actions/runs/42458444443), attempt 1, conclusion `success` |
| Evidence | branch `evidence/run-42458444443-1`, commit `56bb575d5fdbbb843e7e16c56b2b0d15eaaba6f5` (`acceptance-report.md`, `.json`, logs, 88 screenshots, Release app zip, contact sheet) |
| Runner | GitHub `macos-15` image 20261104.0514.1, macOS 15.8.2, Xcode 16.4 (16F6), Swift 6.1.2 |
| Simulator | iPhone 17, iOS 26.2 (23C54) |
| Android canonical source | `F:/Projects/NoirLedger` at `438e316c06ede34a04b0b90f058cbbdd3cb1ced3` (read-only) |
| `shared-assets/asset-manifest.json` SHA-256 | `9018da2f4825ef40d9ca9cd813fa01776c06ebbbd2026d928c34a7899c941636` |

Every commit after `aed8f35` changes files under `docs/` only. The trees `App`, `Packages`, `AppTests`, `UITests`,
`scripts`, `.github`, `project.yml` and `shared-assets` are byte-identical to `aed8f35` (same git tree hashes), so
the build inputs proven by run 42458444443 are unchanged.

**Open gate: native CI on the exact final HEAD.** Unchanged inputs do not replace a run on the final commit. The run
dispatched for the first docs commit `5081b1c` (run 42460957805, conclusion `failure`) started neither job. Both jobs
carry this GitHub annotation verbatim:

> The job was not started because recent account payments have failed or your spending limit needs to be increased. Please check the 'Billing & plans' section in your settings

No billing change or paid overage is authorized, so no further run was dispatched. Until the account owner resolves
this and a full run on the final HEAD succeeds, the exact-final-HEAD CI gate is **BLOCKED**.

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
| Side-by-side parity sheet (installed icons, all five district motifs, North Quay detail, NG+ ledger, contact sheets) | PASS after inspection | [parity/android-ios-parity-sheet.jpg](parity/android-ios-parity-sheet.jpg) |
| Runtime art parity (product seals, crew portraits and role marks, front-business marks) | PASS: verified on real captures on both platforms; see "Runtime art parity" | [parity/runtime-art-parity-sheet.jpg](parity/runtime-art-parity-sheet.jpg), [parity/runtime-art-match.json](parity/runtime-art-match.json) |
| Native CI on the exact final HEAD | **BLOCKED**: run 42460957805 started no job (GitHub billing annotation, quoted above) | — |
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

The layouts differ by design (native Material vs native iOS chrome). In this sheet, the icon and district rows are
verified runtime parity. The contact-sheet row proves only that the canonical files are identical: on that row,
portraits, seals and front marks appear as canonical renders, not on runtime screens. Their runtime coverage is
established separately below.

### Runtime art parity

[parity/runtime-art-parity-sheet.jpg](parity/runtime-art-parity-sheet.jpg)
(SHA-256 `9aa047170a2da9b726fb51543b2bdec436d61873ca20af916cf5c9554757504b`) pairs real Android and iOS runtime
captures of product seals, crew portraits with role marks, and front-business marks. It contains capture pixels only
(cropped and scaled, never redrawn), plus text labels. A one-off composer in the ignored `.qa/` directory produced it;
`scripts/qa/parity_sheet.py` and the original sheet (SHA-256
`b8794527d3d2582951bacbc3480b81c7b20ad4d5aae39b321abe346eae4002b1`) are unchanged.

| Subject | Android capture (SHA-256) | iOS capture (SHA-256) |
| --- | --- | --- |
| Crew portraits Brandt and Varga, Production and Logistics role marks | `33_crew_portraits.png` (`8515d6e540de3598c7eb5d7848b31f77fb9dea8299fb80f944ee906c72777017`) | `en_tour_15_crew.png` (`f164077db4e50a9ff7a4c05600a0e96c4c0748bf334055e0b7db89e38e3cca47`), `en_tour_16_crew_candidates.png` (`083fba98d9ec81ca00da81e72291f017bd0a342336c666ea3b60147f961ef9f6`) |
| Front marks Clearwater Laundromat and Quay Cabs | `35_money_fronts.png` (`92e9fca064fe52c5564f9f273fda0bc50a8d5aa33245aa831d49aff11f01a358`) | `en_tour_14_fronts.png` (`ba3f3f20398147df1fbec7b71136c5bb2cdd5f14d88f1d66894fc069e6198668`) |
| Product seals Glimmer, Cinder, Velvet (iOS also Halo) | `05_ops_line_started.png` (`27f2213de16e345957a2677bd9000135d2af6c8f712426397afcc84592d5d761`), `28_ops_locked_lines_en.png` (`dfb8273078ef92e91fa8f53d50d0d46586ea537379e062c512354502dbf20123`) | `en_tour_06_operations.png` (`891d58c11d659ad143840a88e91597b9ab4070a47b79547e44d039807677ecf6`), `en_tour_07_operations_lines.png` (`75d13f4fc84df404965407fe351298de782cb88e5979ee81779185ae6055f3d6`) |

Provenance:
- **iOS captures.** They come from run 42458444443 at `aed8f35`. Each file is byte-identical to its git blob on
  evidence commit `56bb575` (`git hash-object` equals `git ls-tree`).
- **Android captures.** They are the Android lane's runtime captures in
  `F:/Projects/NoirLedger/.qa/pass2/`, taken 2026-11-07 20:40–20:49 +01:00 and read without modification. For this
  art they are equivalent to the final build at `438e316`:
  - the masters (`shared-assets/products`, `crew`, `roles`, `fronts`) last changed in `7a765e7` (2026-11-07 20:14 +01:00);
  - Android's resource exports for them are unchanged from `7a765e7` to `438e316`, by read-only `git diff --name-only`;
  - the later commits changed other assets (district masters and their exports, brand-mark exports and the manifest), never these four groups; the final district art is covered by the `.qa/final` captures above.
- **Pixel verification.** The art shown is confirmed directly on the pixels, using normalized cross-correlation over
  scale and offset, with a different asset of the same kind as a negative control
  ([runtime-art-match.json](parity/runtime-art-match.json), SHA-256
  `ab8fc1afe4a2a7ed643abd5631b3dd9d34bce1a9faa422691d26ff38bfe46a5d`):

| Art | Reference | Android score (control) | iOS score (control) |
| --- | --- | --- | --- |
| Brandt portrait | master `crew/portrait-brandt-384.png` | 0.893 (Varga 0.474) | 0.815 (0.378) |
| Varga portrait | master `crew/portrait-varga-384.png` | 0.877 (Brandt 0.475) | 0.529 (0.229) |
| Glimmer seal | master `products/seal-glimmer-256.png` | 0.932 (Halo 0.732) | 0.998 (0.693) |
| Velvet seal | master `products/seal-velvet-256.png` | 0.942 (Cinder 0.417) | 0.895 (0.423) |
| Laundromat front mark | the other platform's capture (SVG-only master) | 0.922 against iOS (taxi 0.318) | — |
| Taxi front mark | the other platform's capture | 0.934 against iOS (laundromat 0.306) | — |
| Production role mark | the other platform's capture | 0.888 against iOS (logistics 0.456) | — |
| Logistics role mark | the other platform's capture | 0.919 against iOS (production 0.463) | — |

Every pair scores clearly above its control. Front and role marks have SVG-only masters and no local rasterizer, so
they are matched across the two platforms. The iOS side is the byte-verified canonical export (`ASSET_PARITY_OK`).

Visual inspection: the same subjects are paired, with the same silhouettes and seal geometry. The differences are
platform tinting of template marks (Android amber/brass on leather tiles; iOS paper ink on paper fronts, light ink on
crew panels), which the parity contract allows, plus Android's dimmed Velvet seal on a locked line. Result: **PASS**.

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
