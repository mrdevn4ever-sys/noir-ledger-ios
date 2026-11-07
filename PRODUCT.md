# Product

<!-- impeccable:product-schema 1 -->

> Source of truth: `IOS_GAME_BRIEF.md` (owner-provided, binding), `docs/reference-game-rules.md` (binding systems and
> numbers) and the owner's implementation commission. No interview round was possible in this session (no question tool;
> the owner instructed to derive these files from the brief and moodboard). Facts below come from those documents;
> items marked *(inferred)* are readings of them, not owner statements.

## Platform

ios

## Stack

Owner-pinned: native Swift and SwiftUI, portrait iPhone only, bundle ID `io.puredevn.noirledger`. No Flutter, React
Native, WebView or shared cross-platform UI. Deterministic core in the local Swift package `NoirCore`; project generated
by XcodeGen; Apple-SDK builds and tests run on GitHub-hosted macOS runners only.

## Users

Adults who enjoy deep management and idle/tycoon games and want a serious, believable crime-noir setting instead of a
cartoon. They play on an iPhone held in portrait, often one-handed and in the evening, in short check-ins after time
away and occasionally in longer planning sessions *(inferred)*.

## Product Purpose

NOIR LEDGER is a complete premium offline management game: the player inherits a single cellar operation in the fictional
river city of Varnholm and ends a finished six-chapter campaign controlling the city's entire underworld, then begins
New Game+ with permanent legacy perks. Success means a new player can finish the briefing without help, win the
campaign, see the epilogue and start New Game+, with every system genuinely interlocking and every save surviving
relaunches.

## Positioning

A management game whose spine is the ledger itself: three accounts (dirty cash, clean cash, influence) and a visible,
predictable Heat model turn every expansion into a bookkeeping decision about exposure against cover. Investigations
are announced with a countdown, raids are fair and always recoverable; tension comes from reading the books, not from
random punishment.

## Operating Context

- Paid upfront, one purchase. No ads, no in-app purchases, no subscription, no StoreKit, no account, no network,
  no analytics or tracking, no third-party SDKs.
- Sessions alternate between active play (decisions, events, Heat management) and up to eight hours of offline time
  credited on return with a summary; clocks set backwards credit nothing.
- German and English, following the system language with a manual override in Settings.
- This commission ships source, a simulator build, green tests and simulator screenshots; it never signs, uploads or
  touches App Store Connect.

## Capabilities and Constraints

- Systems: production lines with three upgrade tracks, shared stash, routes per district and product, three accounts,
  five laundering fronts with working reserve, protection network and civic donations, Heat with warning,
  investigation countdown, bribes, lying low and recoverable raids, twelve named crew in six roles with traits, wages
  and loyalty, five improvement branches with tier-2 trade-offs, fifteen authored decisions, six chapters, a
  three-phase final operation, epilogue, books and credits, legacy points, perks and New Game+.
- Fictional world only: invented goods (Glimmer, Cinder, Velvet, Halo), organisations, people and places. No real
  substances, recipes, dosages, sourcing, brands, explicit consumption, gore or sexualised violence. Serious adult
  tone, at most dry black humour, never glorifying.
- No placeholder art, dead buttons, "coming soon", TODO/FIXME, test-only production UI or hard-coded player-facing
  strings. A Debug-only QA accelerator exists for automated tests and is compiled out of Release.

## Brand Commitments

- Name: **NOIR LEDGER** (all-caps wordmark).
- Brief-pinned art direction: dark, realistic neon-noir; black/anthracite ground, aged leather and paper as accents,
  dirty amber/old gold for value, controlled red only for Heat and danger.
- The business ledger is the leitmotif; city, operations and bookkeeping are visually separate.
- Explicitly not: a generic SwiftUI sample, a web-dashboard look, emoji icons, random stock cards, an overloaded poster
  montage behind game information, information surfaces too dark to read.
- Liquid Glass is not adopted for custom surfaces: it conflicts with the opaque leather/paper materiality and would
  raise the minimum iOS version. Standard system chrome may use whatever the SDK provides.
- `docs/noir-ledger-moodboard.png` is direction only, never a shipped background.

## Evidence on Hand

- `IOS_GAME_BRIEF.md`, `docs/reference-game-rules.md`, `docs/PORT_REFERENCE.md`.
- `docs/noir-ledger-moodboard.png`: rainy European river city at night, cellar workshop under a bare bulb, quay
  warehouse, neon club entrance, laundromat, leather ledger with a gold emblem, pinned city map with red route lines.
- No real players, reviews, store copy or press exist; none may be invented.

## Product Principles

1. The books never lie: every number shown is the number the simulation uses.
2. Danger is legible: warnings come before consequences, and every setback can be recovered from.
3. Every screen is a decision, not a menu; systems explain themselves through play.
4. Mood serves reading: atmosphere may never cost contrast, touch size or clarity.
5. Finished means finished: anything shipped works, persists and is reachable in the campaign.

## Accessibility & Inclusion

44×44 pt minimum touch targets; Dynamic Type through the accessibility sizes without clipping core content; VoiceOver
labels and sensible reading order; Reduce Motion, Bold Text, Increase Contrast and Differentiate Without Color honoured;
contrast preserved despite the dark world; full German and English localisation.
