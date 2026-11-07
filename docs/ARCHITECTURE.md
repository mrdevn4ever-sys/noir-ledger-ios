# Architecture

NOIR LEDGER iOS is a native Swift/SwiftUI app with zero third-party dependencies, split into a platform-free
deterministic core and a thin SwiftUI layer.

```
Packages/NoirCore/            Swift package, no UI, no wall clock, no randomness of its own
  Content.swift               ids, authored tables (products, districts, fronts, crew, upgrades, chapters, perks)
  State.swift                 GameState and nested Codable value types (tolerant decoding)
  Economy.swift               SplitMix64 RNG in the state, Mods aggregation, every formula
  Simulation.swift            the fixed-step tick: production → sales → laundering → wages/loyalty → influence
                              → Heat → investigation/raid → rolling rates → decisions → campaign
  Events.swift                15 authored decisions, eligibility, frozen units, outcomes
  Campaign.swift              briefing steps, chapter objectives/rewards, final operation
  Engine.swift                actions (pure: state in → state out), new game, online tick, offline credit, New Game+
  SaveCodec.swift / SaveStore.swift   versioned envelope, raw-JSON migrations, sanitising, atomic primary/backup
  Tests/NoirCoreTests         Swift Testing suite incl. deterministic playthrough bot (runs with `swift test`)
App/                          SwiftUI app target (iOS 17+)
  NoirLedgerApp.swift         scene, lifecycle (foreground → offline credit + ticking, background → save)
  Model/GameStore.swift       @Observable @MainActor owner of GameState; dispatch, autosave, reset, recovery
  Model/AppSettings.swift     language, motion, haptics (UserDefaults)
  Model/Router.swift          tab and navigation paths
  Localization/               L10n (per-language string tables), formatting, id → key labels
  Design/                     shared tokens + semantic roles, components, shared-asset marks, city map
  Screens/                    one file per area (ledger, operations, city, money, network, endgame, sheets, settings)
  QA/QAAccelerator.swift      Debug-only (#if NOIR_QA) launch-argument accelerator for UI tests
  Resources/                  Assets.xcassets (generated from shared-assets/), en/de .lproj, privacy manifest
AppTests/                     Swift Testing, hosted in the app (localization, store lifecycle, settings, assets)
UITests/                      XCTest UI tests on the simulator + EN/DE screenshot tour
shared-assets/                canonical cross-platform art and tokens (byte-identical with Android)
project.yml                   XcodeGen specification (the .xcodeproj is generated, not committed)
```

## Determinism

- Simulated time (`GameState.time`) is separate from the wall clock. The engine never reads a clock; the app passes
  `nowMs` explicitly and `GameStore` injects the clock, which tests replace.
- All randomness comes from the SplitMix64 stream stored in `GameState.rng` (hex-encoded so saves keep all 64 bits).
- Iteration always follows `allCases` order (never `Set`/`Dictionary` order), so floating-point results do not depend
  on hashing seeds. The same seed and actions produce the same state (`PlaythroughTests.determinism`).
- Online ticks credit at most 5 s at a time; longer gaps go through `Engine.applyOffline`, which credits at most eight
  hours in 2 s steps, pauses investigations, blocks raids and decisions, caps Heat at 74 and keeps loyalty ≥ 10.
  A backwards clock credits nothing and resets the reference.

## Rules parity with Android

The core is a line-by-line port of the Android engine at commit `8a631ba5c1be5d01415f34c983716ccf6b203806` and of
`docs/reference-game-rules.md` (all values identical; the contract tests check them value by value). Platform
navigation and presentation differ; rules and outcomes do not. One measured difference in the *bot* (not the
rules): over seeds 1/42/2024 the greedy autoplayer opens 0/0/1 investigations (peak Heat 69/67/83) where the
reference document mentions "several"; win times (10.5–10.9 h) match the reference range.

## Minimum iOS version: 17.0

iOS 17 provides the Observation framework (`@Observable`, `@Bindable`), `sensoryFeedback`, `onChange(initial:)` and
the scroll/safe-area behaviour the layout relies on, while covering the large majority of active iPhones. No API
newer than iOS 17 is used, so no availability branches are needed; Liquid Glass is deliberately not adopted for
custom surfaces.

## Swift language mode and concurrency

`NoirCore`, the app and the app unit tests compile in Swift 6 language mode with complete strict concurrency. Engine
types are `Sendable` value types; UI state lives on the main actor. The UI-test target uses Swift 5 mode because
XCTest's synchronous test methods drive main-actor XCUI APIs.

## Persistence

See [SAVE_FORMAT.md](SAVE_FORMAT.md). Saves are written synchronously on the main actor after every accepted action,
every 5 s of play and when the app moves to the background, so a process kill loses at most a few seconds.

## Privacy and scope

No network, accounts, analytics, tracking, advertising, StoreKit or third-party SDKs. The privacy manifest declares
only UserDefaults access (reason CA92.1). The app is a paid-upfront product; this repository never signs, uploads or
changes App Store Connect.
