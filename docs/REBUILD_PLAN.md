# Rebuilding the ledger of Varnholm

**Vision:** the building tells you why you got paid. A crate sits on a shelf, a van takes it, a buyer signs for it, and the entry changes what you can afford. The joke is that Leopold's least respectable business keeps the best books in town. Keep the night cartoon, the real goods and the consequences; no instructions or celebration of consumption.

## Progression and milestones

1. **First minute and first return.** Open with one signed estate collection at the cellar door. Hand over the waiting crate for a one-time 20, show the receipt, then choose the cash box, address book or tools. Keep the notary letter optional. Let the player spend the receipt on a real second wagon slot, or keep it for another investment. Regular prices stay unchanged. At return, separate cash actually booked from unsold stock; offer a manual run or the dispatcher when that is the limiting station. A van that nobody drives has zero unattended revenue. Fix durable paid delivery before promoting this milestone.
2. **First half hour.** A signed slip leads to a first capacity decision, then a shift lead, choice of contracts, dispatch and a new quarter. Log first access to each distinct decision under all three starts, not taps or repeated offers. Measure gaps over 0–30 minutes, including the final interval. A gap above 120 s triggers a redesign at that point, not a disguised timer or more free cash. Keep actual booked cash separate from theoretical throughput. Pin the next actionable goal and reveal its floor.
3. **Late game and second business.** After the paid final contract, offer a voluntary business plan. Preview exactly what resets and what remains. Prototype two genuinely different second-run strategies (specialist logistics versus standing contracts) in Python before setting multipliers. Collect stamped pages from contracts really fulfilled. Never reset purchases, the collection, or a player's original business without informed choice; use versioned saves, staged migrations and recovery tests.
4. **Building, controls and feedback.** Separate workers' drop points; verify silhouettes over an entire cycle. At large type, retain the current objective and reachable navigation before secondary numbers. An accepted tap has immediate visual feedback; optional sound and haptics respect settings. Reduced Motion gets the same information without travel animations. Keep local clocks, cached sprites, paused hidden views and background audio loading. Measure late scrolling separately from idle.
5. **Store and release polish.** Capture the real cellar, larger van, full building, contract choice and return in DE/EN. Keep unused marketing art outside the app target after measuring archive size. Verify licensed sources, fair optional purchases, actual StoreKit prices and benefit caps. No fundraising language, fictitious countdowns or paid random packs. Recommend the highest applicable age rating to the owner; no submission or tester invitation.

## M1 candidate (not cleared for TestFlight)

The first playable slice is ready for native testing, not release. The paid transaction journal no longer expires old IDs. A restart now commits a complete replacement before changing the live business; an older build cannot erase a newer save. Exercise staging failure, interrupted installation, redelivery after 1,005 intervening purchases, and schema-1 migration in native tests before promotion.

- **Model before code:** `scripts/qa/estate_opening.py` picks the pickup amount (20 is the smallest that pays the
  unchanged 20 van level for every start; wallets after the confirmed upgrade 60 / 0 / 0). The historical baseline
  `scripts/qa/flow_opening.py` is unchanged (first booking 16.5 s; 20 cash at 0 / 38 / 48.75 s).
- **Opening:** `FlowAction.collectEstate` books 20 once as `LedgerKind.estate` (no delivery counted, no recurring
  income), then the heirloom choice (one line each), notary letter optional. The first van level is offered and
  confirmed at the van; the van draws its crate slots (1 → 2). `Flow.hint` only suggests an upgrade the cash covers
  and otherwise keeps the manual chain moving.
- **Return:** `Flow.returnAdvice` (affordable hire → send the van → start an idle bench; upgrades only for a fully
  staffed chain; nothing while the van drives) with a button that acts on the tap, plus the next hire and the cash
  still missing. Measured income is the plain sum booked in the last 60 s; the forecast is labelled "with the chain
  running".
- **Paid delivery:** grant + transaction id in one save, finish only after the write; unfinished transactions retried
  at launch without the catalogue; old UserDefaults markers adopted; ids kept on reset. Silent-partner copy now
  derives 24 h from `FlowContent.offlineCap`.
- **Saves:** schema 2 with `FlowMigration`, pre-migration copy, damaged-file set-aside, lossy ledger lines.

### What the first simulator tour showed

The first playable build ([screens, including the large German offer](https://github.com/mrdevn4ever-sys/noir-ledger-ios/tree/0fbcb3c1c936b2a20c4a470fc52ee519f63f8b7a/screenshots)) reached receipt / confirmed upgrade in 2.42 / 16.22 s (cash box), 1.92 / 18.93 s (address book), and 2.40 / 13.51 s (tools). These are automated, unaccelerated iPhone 17 simulator times, not human playtest data. The app job passed on that revision, the separate core job did not. The lead-only return screen actually showed +0, the full shelf and the dispatch action.

At enlarged text the van offer covered both the depot level and the customer sign. Replace the floating offer and separate instruction with one expandable delivery slip immediately above the street. It grows with text, leaves both station controls exposed, and charges only on confirmation. The stationary depot button announces capacity per trip for VoiceOver; the roof keeps its visual slots. Check cancel, purchase and the new framing in both languages. On the later [wallet and timing run](https://github.com/mrdevn4ever-sys/noir-ledger-ios/actions/runs/44769463021), 27 hosted app tests passed, including restart write failure and redelivery; the cash-box test timed out trying to read the animated roof. Do not count that run as a timing pass.

### Latest opening evidence and scroll blocker

On `d37d69c`, the [focused simulator run](https://github.com/mrdevn4ever-sys/noir-ledger-ios/actions/runs/44774191673) passed: receipt / confirmed purchase in 1.58 / 8.32 s (cash box), 2.19 / 14.12 s (address book), 1.47 / 7.87 s (tools), measured from the interactive screen. That does not clear release: the [three-round comparison](https://github.com/mrdevn4ever-sys/noir-ledger-ios/actions/runs/44774330811) regressed on late scrolling and hot-quarter hitch time against `1d69565`. The next candidate moves timed crew travel into per-floor compositing and avoids reformatting a moving van's unchanged cargo. This is a hypothesis until measured; no change to the meter, scene fixtures, or swipe path. Use `scripts/qa/perf_gate.py LOG BASE_SHA CANDIDATE_SHA 3` on the full job log; require all six scenario/motion medians for both p95 and hitch time. Keep the [art, motion and sound list](HERMES_ASSET_BRIEF_REBUILD.md) separate from evidence of shipped assets.

The [full tour on `d37d69c`](https://github.com/mrdevn4ever-sys/noir-ledger-ios/actions/runs/44774199099) passed. The [German offer](https://github.com/mrdevn4ever-sys/noir-ledger-ios/blob/b83a4b9e14dfc420bf30dd3fc51b182395dcb275/screenshots/de_tour_21_large_van_offer.png) no longer covers either station. The [English original](https://github.com/mrdevn4ever-sys/noir-ledger-ios/blob/b83a4b9e14dfc420bf30dd3fc51b182395dcb275/screenshots/en_tour_21_large_van_offer.png) still shows a truncated customer sign and a partially obscured dispatcher price. Anchor the hire price above the road, give the customer sign the house width and enough height, and check the actual separation between the hire and Go actions. Repeat the large-text purchase in both languages on the iPhone SE (3rd generation), not just the standard phone. `compact/` contains a separate xcresult summary and native screenshots; presence and resolution do not replace visual review. The first order's side-by-side comparison, pinned goal and all-quarter attention preview are M2.

## Evidence and promotion

- From the **first interactive screen**, aim for first visible player-triggered booking ≤5 s and first confirmed upgrade ≤20 s. Measure all three starts in unaccelerated UI tests. Python establishes affordability and required actions, not how fast a person reads or acts. Keep the original [baseline](../scripts/qa/flow_opening.py) for comparison.
- First return: test a lead-only cellar, a van already in transit, an empty cellar and an automated business. Capture actual stock, booked cash, available funds and the next action. Reopening the same save cannot pay twice. Load an established build-56 Flow business with crew, orders, offline clock and entitlements. A pre-upgrade business never receives the estate pickup retroactively.
- Paid favors: persist credit and verified transaction ID together; only then finish the transaction. Force a write failure and a relaunch after a successful write before acknowledgement. Redelivery must end with exactly one credit. No real purchases for these tests.
- For each milestone: localization, asset parity and repository scan green; `ios.yml` green at the candidate SHA; inspect native screenshots in both languages and enlarged text. Compare idle and scroll p95 and hitch time against the previous accepted revision with `perf.yml` on the same runner. Only after these gates, upload the internal TestFlight build and report its number. Simulator frame averages do not certify ProMotion.
- In a first-session playtest, ask the player what changed most and what they want to do next without prompting. A useful surprise and a legible next goal are session outcomes; no bot proves enjoyment, D1/D7, or conversion.
