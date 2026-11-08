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
| `-qa-scenario NAME` | `chapter2`…`chapter5`, `final_ready`, `won`, `ngplus`, `investigation`, `raid`, `event`, `rich` |
| `-qa-timescale X` | game seconds per real second (shortens waits; rules unchanged) |
| `-qa-away S` | pretend the app was closed S seconds (offline summary) |
| `-qa-corrupt-save` / `-qa-future-save` | damage the primary save / write a newer-schema save before loading |
| `-qa-quiet` | no new decisions during the session (stable screenshots) |

Scenarios only skip play time (unlock districts and fronts reached in earlier chapters, add money, hire regulars);
`won` and `ngplus` play the final operation through the engine's own actions. The Release build is scanned for the
accelerator's symbols and strings on every CI run (`release-exclusion.log`).

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
