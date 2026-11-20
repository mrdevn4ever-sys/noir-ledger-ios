# Production brief: receipts, contracts and a second business

Deliver to the integration owner for `rebuild/varnholm`, not to the old source branch. This is a production list, not a claim that these assets have shipped. Inherit §§0–0.1 and the audio delivery rules in §14 of `HERMES_ASSET_BRIEF_4.md`; consult `HERMES_ASSET_BRIEF_4B.md` for the pinned-paper and window-kit references. No public writes from an asset worker. No text baked into art: all numbers, prices, route names and captions come from real DE/EN state.

## What stays, what changes

* **M1:** Keep the street, receipt, real cash amount, van and its roof slots. Make the purchased second slot readable over the night sky without concealing either building sign. Keep `sfx_stamp` for the actual booked pickup, not the preview; no paid reward FX. Reuse the existing worker flipbooks, remove display-rate layout work; check actual motion and the no-motion pose.
* **M2:** Quiet and loud orders must read as different liabilities, not as a larger pile of reward coins. Reuse `OrderQuiet` / `OrderLoud`, present price and attention as text. Use the new signed tab only once an order is actually fulfilled. Give a newly reached objective one short ink cue; use existing `sfx_ink` before commissioning another sound.
* **M3:** Give earned contracts a visible home in the business plan. New closed binder and earned tab, a short stamping motion, and one paper-turn sound. Do not show a stamp for an offer, preview or an unpaid contract. Keep permanent entitlements out of reset effects.
* **M4:** Fix worker drop points and silhouettes in layout before redrawing any sheets; test a full loop on the shelf, both directions. No new global timer. Verify legibility in reduced motion, large type, VoiceOver and at phone size.
* **M5:** Use actual runtime captures for the listing (cellar → bigger van → contract choice → full building → return); not the six unused background plates. Reuse the music/ambience beds. Test gain, cue collisions, muting and resume during ordinary play; a file-level loudness measurement is not a listening verdict.

## Image delivery: four named outputs

For each stem below: `App/Resources/Assets.xcassets/<Stem>.imageset/<Stem>.png` + its `Contents.json` (universal, no scale). PNG, 8-bit sRGB with clean alpha on every frame, 2 px clear border minimum. Dimensions below are pixels at @3x. Use 3 px ink contours (`#1B1B28`), cool night fill, one cel shadow and one warm highlight; no perspective change, readable text, trademarks, consumption or real-world instructions.

| Stem | Frames · size | Prompt and use |
|---|---|---|
| `VanSlotBrass` | 1 × 54 × 42 | A single empty wooden van socket in side view, squared corners with one brass staple at each end; match `CrateSlot` but separate its top lip from the dark depot. Keep an empty center and a flat bottom. Must read empty at 18 × 14 pt; full crates use the existing commodity sprite. |
| `PlanBinderClosed` | 1 × 216 × 216 | One closed navy municipal ledger in three-quarter view, brass hinge and an exaggerated string clasp, worn cream paper edge like `PanelPaper`. Blank cover, not a badge or treasure chest. Clear silhouette at 42 pt. |
| `ContractTabEarned` | 1 × 144 × 108 | A folded cream paper index tab with the corner of a burgundy impression across the fold; two staples catching storefront light. No currency, words or numbers. Distinct from a yellow actionable offer even in grayscale. |
| `ContractImprint6` | 6 × 144 × 108; strip 864 × 108 | Same registered tab and camera as `ContractTabEarned`; isolate only ink and the stamp head on transparent background. Frames: hovering head, descent, contact, slight squash, lift with ink visible, settled imprint. One-shot at 12 fps, no flashing; reduced motion uses the static earned tab instead. |

## Sound delivery: one named output

`App/Resources/Audio/sfx_plan_page.m4a`: 0.32 s, 44.1 kHz mono AAC-LC. Prompt: a stiff paper leaf bends, slips past a brass ring, then settles. Dry, close, no voice, melody, sampled recording or cash-register chime. Original deterministic synthesis: a filtered noise sweep with a quieter second paper contact; fast fade-in, quiet tail, decoded sample peak around −9 dBFS (±1 dB). Schedule once on a real page transition and only when sound is enabled; do not loop on scroll or charge for turning a page.

## Acceptance and provenance

Stage editable sources, exact prompt or generator recipe and hashes outside the repo. Submit a dark/cream comparison at native and literal phone sizes plus a 12 fps playback for the strip. Reject detached alpha or visible matte edges. Check the six frames against a single anchor; capture the real DE/EN state before and after the earned stamp. Deliver audio with decoded duration/channels/rate, peak and end-boundary measurement; separately record whether it was heard on a device. Credit each integrated path in `docs/asset-credits.json` with exact origin and commercial-use rights. No credits for proposed assets. The existing scene and audio bundle remain usable before these replacements are accepted.
