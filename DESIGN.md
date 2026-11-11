# Design

<!-- impeccable:design-schema 1 -->

> Durable visual truth for NOIR LEDGER iOS, written from the built app. Direction is brief-pinned
> (`IOS_GAME_BRIEF.md`, moodboard `docs/noir-ledger-moodboard.png`), so no concept roll was run; the surface is an
> Operate surface, built code-first. Colours, marks and illustrations are shared with the Android edition through
> `shared-assets/` (see `F:/Projects/NOIR_LEDGER_ASSET_PARITY.md`).

## World

A rainy European river city at night, read through a leather-bound ledger. Three section materials keep city,
operations and bookkeeping visually apart while every control stays a standard iOS control:

| Section | Surface | Where |
| --- | --- | --- |
| Books | aged paper (`paper` #E6D8B8) with paper ink (`paperInk` #2A2117) | Ledger chapter page, accounts, bookings journal, owned fronts, decision choices, briefing coach, epilogue books |
| Workshop | ledger leather (`leatherDark` #2A1D14, foil edge `brassDark`) | stash, production lines, crew |
| Night city | anthracite (`surface1`) with a cold `teal` edge | city map, district cards and detail, routes |
| Chrome | near-black `ground` and `surface1` | header, tab bar, settings, sheets |

**Signature move:** the city drawn as the pinned map from the owner's desk: the river, five district pins with control
rings, and route threads running from Leopold's cellar. Threads are amber; a district turns red only while it is under
investigation or closed by a raid.

## Colour (shared token map)

All colours come from `shared-assets/tokens/tokens.json`, mirrored verbatim in `App/Design/Theme.swift`
(`SharedTokens`, checked by `scripts/shared_assets.py check`). iOS semantic roles map onto them:

| Role | Token | Meaning |
| --- | --- | --- |
| ground / surface / raised / track | `ground` #0F0D0B, `surface1` #17140F, `surface2` #201B15, `surface3` #2A241C | anthracite layers |
| ink / inkSoft / inkMuted | `ink` #E9DFC9, `inkSoft` #B9AC93, `inkFaint` #8A7F6C | text on dark |
| dirty cash, primary action | `amber` #E0A43A on `onAmber` #1C1307 | value, live state |
| clean cash | `gold` #C8A55A | completed value |
| influence | `teal` #8FA6A0 | secondary accent |
| Heat and danger only | `red` #E0483C, container `redDim` #5A1E19 | never decoration |
| foil | `brass` #D19E4A, `brassDark` #8C6630 | marks, meters, borders on paper |

Strategy: restrained. Neutrals carry the screen, amber marks value and the primary action, red appears only for Heat.
Text pairings meet 4.5:1 (`inkFaint` is not used on leather; small text on paper uses paper ink, not foil).

## Type

San Francisco for all UI through Dynamic Type text styles; numbers use `monospacedDigit()`. Display moments (chapter
titles, story pages, epilogue, final operation) use Apple's New York serif (`Font.display`), still Dynamic Type aware.
The brand wordmark is the shared `brand/wordmark.svg`.

## Marks and illustrations

Branded artwork is never an SF Symbol. From `shared-assets/` via the asset catalog:

- four product seals (Glimmer six-dot ring, Cinder hexagon with bar, Velvet diamond with centre dot, Halo rings);
- five district illustrations as card banners and detail headers (final Android masters from `438e316`: dark
  silhouettes against a warm, backlit horizon haze, legible on the anthracite cards);
- twelve crew portraits; five front, six role, five branch and seven status marks (template-tinted);
- ledger emblem, wordmark, app icon (leather ledger, double gold frame, lozenge, clasp).

SF Symbols remain only for system chrome: settings, chevrons, locks, play/pause, checkboxes.

## Components

- `Panel(surface)`: one opaque surface per group, 14 pt continuous corners, 1 pt edge; never nested; rows split by
  `PanelDivider`.
- `NoirButtonStyle`: primary (amber), secondary (raised + hairline), danger (redDim), quiet. 44 pt minimum height.
- `UpgradeButton`: action plus its cost; disabled with an accessibility hint when unaffordable.
- `HeatGauge`: ruled 0–100 scale with marks at 50 and 75, trend dot, status text and mark.
- `Meter`, `ValueRow` (stacks label over value at accessibility sizes), `StatusChip`, `RequirementLine`, `CostLine`.
- Native controls throughout: `TabView` (5 sections), `NavigationStack` push for districts, final operation, legacy and
  epilogue; sheets for decisions, raid, return summary and settings; segmented pickers; `Toggle`; `Form` for settings;
  alerts and confirmation dialogs for reset, dismissal and New Game+.

## Empire scene (version 2.0)

The home tab is the operation in cross-section: the rainy street with the skyline, the signs of the owned fronts and
the delivery van; the stash as filling shelves; one lit room per production line with its apparatus, crew silhouettes
and a crate belt. Rooms grow through four tiers as the line passes milestones. Everything is drawn in
`App/Design/EmpireArt.swift` (Canvas + TimelineView at 30 fps, frozen under Reduce Motion). Delivered artwork replaces
the drawings without code changes: `Room<Product>0…3`, `SceneStreet`, `SceneStash`, `SpriteWorker` (see
`docs/HERMES_ASSET_BRIEF.md`). Scene-only tints (`SceneTint`): ember for Cinder, plum for Velvet, ice for Halo.

Feel: numbers roll (`RollingText`), taps and finished batches throw floaters, milestones/chapters/new starts raise a
gold banner with a burst, and every moment has a sound (`SoundEngine`, files in `App/Resources/Audio`).

## Motion

Press feedback 80–160 ms (scale 0.97, or a dim under reduced motion), prologue page fades 200 ms. The empire scene
loops continuously by design (rain, lamps, crew, van); all of it stops under Reduce Motion. The Motion setting (system / reduced / full) combines with the system Reduce Motion flag.
Haptics: selection on accepted actions, warning on rejected ones (setting-controlled).

## Layout

Portrait iPhone. Pinned accounts/Heat header at the top of every section, the briefing coach and notices inset at
the bottom, scrollable content between, 16 pt gutters on a 4 pt rhythm. Liquid Glass is not adopted for custom
surfaces (opaque leather/paper world, iOS 17 minimum); system chrome uses whatever the SDK provides.

## Accessibility

44×44 pt targets, VoiceOver labels on composite rows (accounts, Heat, objectives, map pins), headers marked, Dynamic
Type through accessibility sizes (header and rows reflow vertically), status always as text plus mark, never colour
alone.
