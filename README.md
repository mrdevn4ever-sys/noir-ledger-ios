# NOIR LEDGER — iOS

A complete premium offline management game for iPhone: inherit a cellar operation in the fictional river city of
Varnholm, build production, routes and laundering fronts, manage Heat, crew and rivals across six chapters, win the
three-phase final operation, read the epilogue and start New Game+ with permanent legacy perks. Native Swift and
SwiftUI, portrait iPhone, German and English, no account, network, ads, analytics, tracking or in-app purchases.

- Binding brief: [IOS_GAME_BRIEF.md](IOS_GAME_BRIEF.md) · rules and numbers: [docs/reference-game-rules.md](docs/reference-game-rules.md)
- Provenance (Android parity): [docs/PORT_REFERENCE.md](docs/PORT_REFERENCE.md) · shared art: [shared-assets/](shared-assets/)
- Product and design truth: [PRODUCT.md](PRODUCT.md), [DESIGN.md](DESIGN.md)
- [Architecture](docs/ARCHITECTURE.md) · [Save format](docs/SAVE_FORMAT.md) · [QA and accelerator](docs/QA.md) · [Acceptance](docs/ACCEPTANCE.md)

| | |
| --- | --- |
| Bundle ID | `io.puredevn.noirledger` |
| Minimum iOS | 17.0 (iPhone, portrait) |
| Language | Swift 6 (app, core, unit tests), SwiftUI, zero third-party dependencies |
| Project | generated from `project.yml` with XcodeGen |

## Build and test (macOS with Xcode 16 or newer)

```bash
brew install xcodegen
xcodegen generate                               # creates NoirLedger.xcodeproj from project.yml
open NoirLedger.xcodeproj                       # run the NoirLedger scheme on an iPhone simulator

# deterministic core (no simulator needed)
(cd Packages/NoirCore && swift test)

# app unit tests + UI tests on a simulator
xcodebuild test -project NoirLedger.xcodeproj -scheme NoirLedger \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO

# Release simulator build (contains no QA accelerator)
xcodebuild build -project NoirLedger.xcodeproj -scheme NoirLedger -configuration Release \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

Static gates that run on any host:

```bash
python3 scripts/check_l10n.py         # EN/DE key parity, format specifiers, no literal player-facing text
python3 scripts/shared_assets.py check   # shared-asset hashes, iOS exports, colour tokens
python3 scripts/scan_repo.py          # TODO/FIXME/placeholders, drug terms, network/ads/billing/tracking, secrets
```

## Continuous integration

`.github/workflows/ios.yml` (manual `workflow_dispatch`) runs on a GitHub-hosted `macos-15` runner: core `swift test`,
static gates, XcodeGen, simulator selection from the runner inventory, Debug unit + UI tests with a result bundle,
screenshot and summary export, Release build with a QA-exclusion binary scan, a contact sheet from the canonical
assets and a provenance report. Evidence is uploaded as artifacts and, because the account's artifact storage quota
can be exhausted by other repositories, also pushed to an `evidence/run-<id>-<attempt>` branch of this private
repository.

## Playing

The first launch opens the prologue; the seven-step briefing teaches production, routes, selling, fronts, laundering
and Heat through real actions. Progress is saved automatically after every action, every few seconds and when the app
leaves the foreground; up to eight hours away are credited with a summary. Settings hold the language (system,
Deutsch, English), motion, haptics and a confirmed campaign reset.

## Shared assets with Android

`shared-assets/` is copied byte-identically from the Android repository (`python3 scripts/shared_assets.py sync
--from <android>/shared-assets`), and every iOS export (app icon, imagesets) is generated from it with
`python3 scripts/shared_assets.py export`. Never edit the masters here; change them in the canonical pack and resync.

## Scope

Source, simulator build, tests and simulator evidence only. No code signing, certificates or provisioning, no
TestFlight, App Store upload or App Store Connect changes, no releases. The game is fiction: every person, place,
organisation and good is invented.
