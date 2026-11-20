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

Known gaps in M1: no swipe/large-text check of the van card on the smallest supported phone yet; the first order's
side-by-side comparison, pinned goal and all-quarter attention preview are M2.

## Evidence and promotion

- From the **first interactive screen**, aim for first visible player-triggered booking ≤5 s and first confirmed upgrade ≤20 s. Measure all three starts in unaccelerated UI tests. Python establishes affordability and required actions, not how fast a person reads or acts. Keep the original [baseline](../scripts/qa/flow_opening.py) for comparison.
- First return: test a lead-only cellar, a van already in transit, an empty cellar and an automated business. Capture actual stock, booked cash, available funds and the next action. Reopening the same save cannot pay twice. Load an established build-56 Flow business with crew, orders, offline clock and entitlements. A pre-upgrade business never receives the estate pickup retroactively.
- Paid favors: persist credit and verified transaction ID together; only then finish the transaction. Force a write failure and a relaunch after a successful write before acknowledgement. Redelivery must end with exactly one credit. No real purchases for these tests.
- For each milestone: localization, asset parity and repository scan green; `ios.yml` green at the candidate SHA; inspect native screenshots in both languages and enlarged text. Compare idle and scroll p95 and hitch time against the previous accepted revision with `perf.yml` on the same runner. Only after these gates, upload the internal TestFlight build and report its number. Simulator frame averages do not certify ProMotion.
- In a first-session playtest, ask the player what changed most and what they want to do next without prompting. A useful surprise and a legible next goal are session outcomes; no bot proves enjoyment, D1/D7, or conversion.
