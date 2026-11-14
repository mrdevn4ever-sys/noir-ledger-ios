# Game rules and balancing

All numbers below are the values in `engine/Content.kt` and `engine/Economy.kt`. Time is in game seconds.

## Resources

| Resource | Earned by | Spent on |
| --- | --- | --- |
| **Dirty cash** | street sales | materials, routes, line upgrades, stash, crew fees, wages and bonuses, pushing rivals, buying the laundromat, final-operation choices |
| **Clean cash** | laundering through fronts, chapter rewards | districts, fronts (except the laundromat), front upgrades, protection, improvements, donations, bribes, the final operation |
| **Influence** | controlled districts (scaled by control), Connections crew, donations, events, chapter rewards | thresholds to move into districts (not spent), bribes, pushes, tier-2/3 improvements, events, the final operation |

## Production

Four product lines (fictional goods with economic profiles only):

| Line | Price | Unit cost | Cycle | Batch | Risk | Demand/min | Opens |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Glimmer | 10 | 2.5 | 8 s | 3 | 1.0 | 30 | start |
| Cinder | 26 | 7 | 12 s | 6 | 0.6 | 36 | chapter 2 (2,500 dirty) |
| Velvet | 90 | 24 | 20 s | 4 | 1.1 | 14 | chapter 3 (15,000) |
| Halo | 480 | 130 | 40 s | 2 | 1.4 | 4 | chapter 5 (90,000) |

Each line has three upgrade tracks (levels 1–10, cost ×1.75 per level): batch size (+50 % per level), cycle
(×0.9 per level) and quality (+10 % price, +4 % demand, +6 % unit cost per level). Materials are paid per batch
in dirty cash. A line without cash stops (`No cash`); the starter Glimmer line instead switches to scrap mode
(half speed, free) so a save can never dead-lock. Output stops when the shared stash is full (120 units,
×1.8 per stash level, 12 levels).

## Distribution

Each district has a route level (0–10) per product. Sales per second are
`min(route capacity, demand)`, limited by stock and shared fairly between districts. Price is
`base × district price × quality × modifiers`. Demand is `base × district taste × (0.5 + 0.5 × control) × quality × route reach`, where route reach is
`1 + 15 % × (route level − 1)` (iOS 2.0: every route level raises sales, not only capacity).
Selling in a district slowly pushes rivals back, up to a presence cap of `15 + 5 × route levels` (max 85 %).
Pushing rivals (60 s cooldown) costs dirty cash and influence, gains 9 control (6 in Foundry Row) and adds Heat
in proportion to the district's police.

| District | Opens | Unlock | Police | Price | Rivals | Special |
| --- | --- | --- | --- | --- | --- | --- |
| Cellar Quarter | start | — | 0.7 | ×0.85 | 40 % | quietest police |
| North Quay | ch. 2 | 1,500 clean | 0.9 | ×0.95 | 65 % | routes ×1.4; control lowers material cost up to 15 % |
| Neon Mile | ch. 3 | 15,000 clean, 60 influence | 1.3 | ×1.25 | 60 % | Velvet/Halo taste, heavy police |
| Foundry Row | ch. 4 | 90,000 clean, 220 influence | 0.8 | ×1.0 | 80 % | hard to push; control speeds production up to 15 % |
| Crown Hill | ch. 5 | 450,000 clean, 650 influence | 1.8 | ×1.7 | 70 % | Halo taste, highest influence income |

## Laundering

Fronts wash dirty cash into clean money automatically (each can be paused). Capacity grows by +50 % per
level (10 levels, paid in clean cash). A working reserve (none / 2 / 10 / 30 minutes of street income) keeps
dirty cash for materials; during the briefing no reserve applies.

| Front | District | Price | Washes/s | Fee | Risk | Cover |
| --- | --- | --- | --- | --- | --- | --- |
| Clearwater Laundromat | Cellar Quarter | 120 dirty | 1.5 | 30 % | 0.25 | 1 |
| Quay Cabs | North Quay | 4,000 clean | 7 | 22 % | 0.30 | 4 |
| Club Half Moon | Neon Mile | 30,000 clean | 32 | 15 % | 0.60 | 10 |
| Stahlmann Construction | Foundry Row | 150,000 clean | 120 | 25 % | 0.15 | 40 |
| Galerie Aurel | Crown Hill | 700,000 clean | 450 | 10 % | 0.35 | 90 |

## Heat, investigations and raids

- **Exposure** = Σ sales revenue/s × product risk × district police + Σ laundered/s × front risk (× modifiers).
- **Cover** = 4 + front cover (×1.3 per level) + protection network (8 × (2^level − 1)) + 2 × √influence (× modifiers).
- **Trend** = 100 × exposure / (exposure + cover). Heat moves toward the trend: rising with a time constant of
  120 s, falling with 200 s (twice as fast while lying low). Pushes and some decisions add Heat instantly.
- **Warning** at 50 ("Watched"). At **75** (from chapter 1) an investigation opens a visible countdown of
  180 s (+90 s with Lookouts) in the district with the most exposure. If Heat falls below 60 (65 with the
  police scanner), it is dropped. Countermeasures: bribe (−18 Heat, clean cash + influence, 120 s cooldown),
  lie low (stops street sales), protection, Counsel crew, improvements.
- **Raid** when the countdown runs out: 50 % of stock and 20 % of dirty cash seized (reduced by Fallback stash and
  Counsel), −15 control in that district (halved with Muscle), streets closed for 120 s, crew loyalty −8, Heat
  reset to 40. Lines, fronts, routes, crew and clean cash are untouched, so a raid is always recoverable.

## Crew

Six roles, one specialist each; twelve named candidates (a regular and a veteran per role, veteran power ×1.7).
Traits change power, wage or exposure. Loyalty rises toward 80 while wages are paid, falls 3/min while unpaid,
drops 8 per raid, and can be raised with a bonus. Below 50 and 25 the effect weakens; at 0 the specialist leaves
and can be rehired for 1.5× the fee. Loyalty never falls below 10 while you are away.

| Role | Effect per power |
| --- | --- |
| Production | +15 % speed, +5 % price |
| Logistics | +20 % route capacity |
| Muscle | +50 % push strength; raids cost half the control |
| Books | +25 % laundering capacity, −3 points fee |
| Counsel | +12 % cover, +30 % Heat cooling, −40 % raid cash loss |
| Connections | +30 % influence, −20 % bribe cost |

## Improvements

Five branches of four nodes: tier 1 (1,500 clean, from chapter 1), then a **choice of one of two** tier-2 nodes
(25,000 clean and 40 influence, from chapter 3), then a tier-3 capstone (200,000 clean and 150 influence, from
chapter 4). Each tier-2 pair is a real trade-off, for example Delivery vans (+35 % routes, +10 % exposure)
against Dead drops (+10 % routes, −15 % exposure). The full list is on the Network → Improvements tab.

## Decisions (events)

Fifteen authored events arrive every 4–7 minutes of active play (never while away or during the briefing). Each
has eligibility rules, at least one free choice, visible costs, and stated probabilities and effects. Cash amounts
scale with your current income and are frozen when the event appears. Effects include cash, Heat, loyalty,
control, closed streets, lost stock and timed modifiers on price, demand, material cost, production or routes.

## Campaign

| Chapter | Objectives | Reward |
| --- | --- | --- |
| 1 A Foothold | earn 3,000 dirty · Glimmer line at 6 total levels · 2 crew · wash 1,500 | 1,000 dirty |
| 2 North Quay | move into North Quay · open Cinder · 55 % control there · Quay Cabs | 3,000 clean, 20 influence |
| 3 Neon Mile | move into Neon Mile · open Velvet · Club Half Moon · 3 improvements · wash 60,000 total | 20,000 clean, 60 influence |
| 4 Iron and Smoke | move into Foundry Row · 60 % control there · 5 crew · Stahlmann Construction · hold 400 influence | 150,000 clean, 120 influence |
| 5 Crown Hill | move into Crown Hill · open Halo · Galerie Aurel · 50 % control there | 400,000 clean, 200 influence |
| 6 The Ledger | final operation (below) | campaign win, legacy points |

**Final operation.** Requirements: every district at ≥70 % control, 1.2 M clean, 1,200 influence, Heat < 50.
Starting it pays a war chest of 50 % of the clean requirement and 40 % of the influence. Phases:

1. The vote — buy the votes (300k clean, certain) · call in favours (300 influence, needs Connections, certain) · lean on the chair (free, 45 %, +12 Heat).
2. The convoy — stop it (150k dirty, Muscle, 85 %, +12 Heat) · reroute (150k dirty, Logistics, 70 %, +4 Heat) · buy the drivers (500k dirty, certain).
3. The commissioner's book — counsel seizure (250k clean, Counsel, 85 %) · trade for silence (250 influence, Connections, 75 %) · burn the archive (400k dirty, 60 %, +20 Heat).

Winning shows the epilogue and the books (time, earnings, raids, investigations, decisions) and credits.

## New Game+

Legacy points per win: 10 + improvements/2 (max 8) + 3 without raids + investigations survived (max 4). Perks:
Starting capital (+2,000 dirty), Old contacts (+15 % influence), Efficient lines (+10 % speed), Clean books
(−2 fee points), Cold trail (+15 % cover), each up to rank 5; Known name (−10 % district costs) up to rank 3.
Rank n+1 costs n+1 points. Each New Game+ level adds +5 % starting rival presence and +25 % to the final
operation's requirements and costs. New Game+ skips the prologue and briefing.

## Offline progress

Time away is measured by the wall clock and credited up to **8 hours** at full efficiency, simulated in 2 s steps.
While away: no events, no investigations or raids (Heat cannot rise above 74), an open investigation's countdown
pauses, and crew loyalty never falls below 10. A clock set backwards credits nothing and resets the reference;
absurd forward jumps are capped. Gaps under 60 s are credited silently; longer ones show a summary.

## Balancing assumptions and evidence

- Target: a complete campaign in roughly 10–13 hours of play including idle time, with Heat becoming a real
  constraint from chapter 2.
- `PlaythroughTest` runs a deterministic greedy autoplayer (decisions every 10 s, no offline time) from a fresh
  save. Measured: seeds 1, 42 and 2024 win after about 12.8 h, 10.5 h and 10.4 h with several investigations
  each; a New Game+ run with perks also wins. The test fails if any seed loses, finishes under 4 h or over 20 h,
  or skips a chapter.
- The briefing takes about five minutes of real time.

## Idle layer (iOS version 2.0)

Everything in this section multiplies **payouts** (the cash a sale or a wash brings in), never the units that move.
Exposure and Heat are always computed from the base street economy, so the Heat balance above holds at any multiplier.

- **Stage.** A line's stage is 1 plus every track level and mastery level bought. The one-button upgrade on the empire
  screen buys the cheapest open track, then **mastery** (after all tracks are at 10): +8 % payout per level, cost
  `line upgrade base × 250 × 1.25^level`, up to stage 500. Buy modes ×1, ×10, ×25, MAX.
- **Milestones.** At stages 10, 25, 50, 75, 100, 150, 200, 250, 300, 400 and 500 a line's payout doubles.
- **Tapping** a running line adds one second of work.
- **Global payout** = (1 + 2 % × reputation) × 2 with the silent partner × 2 while a boost runs. Fronts wash boosted
  cash at the same boosted pace.
- **Going to ground** (from chapter 2, at least 10 reputation to gain): ends the run and starts chapter 1 with the
  briefing skipped. Reputation gained = `25 × (dirty earned this run / 250,000)^0.4`, ×1.5 after a campaign win;
  New Game+ books it too. Favors, purchases, legacy perks, achievements and reputation survive.
- **Favors** (premium currency) come from achievements (28, 5–100 each), the daily envelope (7-day cycle: 10 favors,
  1 h boost, 15, 1 h time jump, 20, 2 h boost, 50), each finished chapter (10) and the store. They buy: ×2 boost 4 h
  (40), time jumps 2/8/24 h (30/100/250, simulated like time away), Heat −30 (25), full crew loyalty (20).
- **Sponsor rewards** (one finished video each, or directly with the ad-free upgrade): ×2 boost 30 min (stacks to
  8 h), 3 favors (5 a day), Heat −15 (10 min cooldown), and the street cash earned while away a second time.
- **Store:** starter crate (200 favors + 4 h boost, once), silent partner (permanent ×2, offline cap 16 h), no videos,
  four favor packs (80 / 500 / 1,200 / 3,000).
