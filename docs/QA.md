# QA

## Test layers

| Layer | Where | Runs on | What it proves |
| --- | --- | --- | --- |
| Core unit/integration | `Packages/NoirCore/Tests` (Swift Testing) | macOS host, `swift test` | every formula and content contract, production, sales, laundering, Heat, investigations, raids and recovery, crew, improvements, all 15 decisions, chapters, final operation, legacy, New Game+, offline credit and clock protection, save codec/store/migration |
| Deterministic playthroughs | `PlaythroughTests` | macOS host | a greedy bot plays prologue → briefing → chapters 1–6 → final operation for seeds 1, 42 and 2024 (4–20 h bound), then New Game+ with perks wins again; same seed ⇒ same state |
| App unit tests | `AppTests` (Swift Testing, hosted) | simulator | localization coverage of every derived key, formatting, journal/effect text, store lifecycle (relaunch, offline, backup recovery, future save, reset), settings, compiled shared assets |
| UI tests | `UITests` (XCTest) | simulator | real taps through the flows below |
| Static gates | `scripts/*.py` | any host | localization parity, shared-asset parity and tokens, source scan |
| Release exclusion | `scripts/ci/verify_release_exclusion.sh` | macOS | the Release binary contains no QA accelerator symbol or string |

UI flows (`GameFlowUITests`): fresh install → prologue choice → all seven briefing steps; core systems (line, stash,
new line, route, push, front pause, reserve, protection, donation, hire, improvements, legacy); stash upgrade survives
termination + relaunch with an offline return summary; investigation countermeasures in real time (bribe + lie low drop the
case before the countdown ends); an unanswered investigation at accelerated time → raid → recovery; dismissal with
confirmation and rehiring at 1.5× the fee; final operation
(three phases, regroup after a failure) → epilogue → legacy perk → New Game+; manual language switch and system German
detection; accessibility XL text; reset confirmation; damaged-save recovery; newer-version save protection; the
installed home-screen icon.

## Debug-only campaign accelerator

`App/QA/QAAccelerator.swift` is compiled only with the `NOIR_QA` flag, which `project.yml` defines for the Debug
configuration alone. It has no UI; UI tests drive it with launch arguments:

| Argument | Effect |
| --- | --- |
| `-qa-reset` | erase save and settings before loading |
| `-qa-seed N` | seed for a fresh campaign |
| `-qa-scenario NAME` | 4.x ledger: `cellar`, `neck`, `board`, `chain`, `lead`, `lead-rich`, `harbour`, `night`, `crown`, `late`, `contract`, `finale`, `hot` (see `QAAccelerator.swift`; every scenario starts through the real pickup and choice). Older campaign names in the 2.x history: `chapter2`…`chapter5`, `final_ready`, `won`, `ngplus`, `investigation`, `raid`, `event`, `rich` |
| `-qa-timescale X` | game seconds per real second (shortens waits; rules unchanged) |
| `-qa-away S` | pretend the app was closed S seconds (offline summary) |
| `-qa-corrupt-save` / `-qa-future-save` | damage the primary save / write a newer-schema save before loading |
| `-qa-quiet` | no new decisions during the session (stable screenshots) |

Scenarios only skip play time (unlock districts and fronts reached in earlier chapters, add money, hire regulars);
`won` and `ngplus` play the final operation through the engine's own actions. The Release build is scanned for the
accelerator's symbols and strings on every CI run (`release-exclusion.log`).

## M1 opening and return evidence (rebuild/varnholm)

For quick feedback without cancelling the full screenshot tour on this branch, dispatch `compile.yml` with
`opening=true`. It runs the hosted app tests and all three unaccelerated openings on the selected iPhone simulator.
`OPENING_UI_OK` requires measured receipt and upgrade times for every heirloom; the raw log and result bundle
are retained even on failure. This diagnostic run does not replace `ios.yml`, screenshot review or `perf.yml`.

| Test | Proves | Not proof of |
| --- | --- | --- |
| `OpeningTimingUITests` (three starts, no `-qa-timescale`) | from the first interactive screen (cellar door, after launch) to the visible pickup booking ≤ 5 s and to the confirmed first van level ≤ 20 s; prints `OPENING start=… reward_s=… confirmed_upgrade_s=…` | how fast a person reads or decides; fun or retention |
| `GameFlowUITests.testPrologueFirstDeliveryAndUpgrade` | pickup +20, optional letter, heirloom, van 1 → 2 slots at the van, first ordinary delivery | |
| `GameFlowUITests.testFourMinuteReturnWithoutDispatcher` (`lead`, `lead-rich`) | 4 min away with a lead and no dispatcher books +0; advice is "send the van" (with the hire still out of reach) or "hire the dispatcher" when affordable; it runs only on the tap | |
| Tour shots `*_tour_00`…`02c`, `17b`, `19`…`21` (EN/DE) | door, letter, heirlooms, van offer/confirm/after, lead-only return, accessibility-size opening | a reviewed image until a person has looked at it |
| `FlowOpeningTests` (core) | pickup once, every start can buy the van at 20, the street ticket stays 5, receipts once, schema-1 fixtures, recovery, return advice | the UI |
| `LedgerStoreTests` (app) | relaunch halfway, build-56 business with time away once, forced write failure, redelivery after a write, legacy marker, reset keeps ids | real StoreKit payment (never used in tests) |

## Screenshot inventory

Screenshots are XCTest attachments captured from the running app on the simulator and exported from the
`.xcresult` by `scripts/ci/export_results.py` (`evidence/screenshots/*.png`).

- `en_tour_*` and `de_tour_*` (30 each): prologue, prologue choice, briefing, ledger, books, operations, lines, city,
  district cards (all five illustrations), district detail, routes, money/Heat, fronts, crew, crew candidates
  (portraits), improvements, legacy summary, settings, decision, investigation, raid, offline return, final
  requirements, final phase, epilogue, epilogue books/credits, New Game+, large text ledger and operations.
- `en_0x_*` briefing flow, `en_2x_*` investigation/raid/offline, `en_3x_*` final operation/epilogue/legacy/New Game+,
  `en_4x_*`/`de_40_*` settings, reset, recovery, future save, `en_5x_*` large text, `en_60_home_screen_icon`.

Visual review runs in at most two batched passes; results are recorded in [ACCEPTANCE.md](ACCEPTANCE.md).

## Cross-platform parity evidence

- `scripts/shared_assets.py check` (every CI run): manifest hashes, byte-identical iOS exports, asset names used in
  Swift, and the shared token map.
- Android `tools/assets/compare_parity.py <this repo>`, run read-only with `python -I -B`: byte comparison of both
  `shared-assets/` trees.
- `scripts/qa/parity_sheet.py <android repo> <ios screenshots> <ios contact sheet> <out.png>`: composes real Android
  and iOS runtime captures plus both canonical contact sheets side by side (no redrawing); the accepted sheet is
  [parity/android-ios-parity-sheet.jpg](parity/android-ios-parity-sheet.jpg).
- Runtime art coverage (product seals, crew portraits and role marks, front marks) is paired from real captures on
  both platforms and pixel-matched with negative controls:
  [parity/runtime-art-parity-sheet.jpg](parity/runtime-art-parity-sheet.jpg) and
  [parity/runtime-art-match.json](parity/runtime-art-match.json); provenance is in [ACCEPTANCE.md](ACCEPTANCE.md).
