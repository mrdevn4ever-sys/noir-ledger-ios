# Save format, migration and recovery

## The 4.x ledger: `noir_flow.save` (schema 2)

The playable game writes `FlowSaveStore` files; the `noir_ledger.save` sections below describe the 2.x campaign,
whose wallet is only read once for favors and purchases.

| File | Purpose |
| --- | --- |
| `noir_flow.save` | primary, `{"schema": 2, "savedAt": ms, "state": FlowState}`, sorted keys, written atomically |
| `noir_flow.save.bak` | the previous primary that still decoded |
| `noir_flow.save.tmp` | write in progress (never loaded) |
| `noir_flow.save.pre-migration` | the untouched file of an older schema, copied once before it is migrated |
| `noir_flow.save.damaged` | an unreadable primary, set aside before a fresh game is written |

Loading order: primary → backup → pre-migration copy (each flagged as restored) → fresh game. A schema newer than the
app is never written over (protected screen). "Start over" erases primary, backup, temp and the pre-migration copy.

Schema 2 adds, with safe defaults when missing:

- `state.estate` (`WAITING` / `BOOKED` / `NOT_OFFERED`, default `NOT_OFFERED`): the one-time signed pickup at the
  cellar door. `FlowMigration` gives a schema-1 save `WAITING` only when nothing was chosen, earned, delivered or
  booked; every business already in play gets `NOT_OFFERED` and can never book it.
- `LedgerKind.ESTATE`: the pickup's single ledger line (not counted as a delivery).
- `state.meta.deliveredTransactions`: verified store transaction ids already booked, oldest first, at most 1,000.
  The grant and its id are written in the same save; only then is the transaction finished. The 3.x/4.0 marker
  `store.deliveredTransactions` in UserDefaults is read as a fallback and copied into the save; it is never written
  again. A reset keeps the ids together with favors and the permanent purchases.

Unknown fields are ignored; an unreadable ledger line is dropped on its own instead of emptying the ledger.
Tests: `FlowOpeningTests` (schema-1 business and prologue fixtures, unknown fields, recovery chain) and
`LedgerStoreTests` (relaunch, time away once, forced write failure, redelivery after a successful write).

## Location and files

`Application Support/NoirLedger/` inside the app container:

| File | Purpose |
| --- | --- |
| `noir_ledger.save` | primary save |
| `noir_ledger.save.bak` | the previous save that still decoded |
| `noir_ledger.save.tmp` | write-in-progress file (never loaded) |

Settings (language, motion, haptics) live in UserDefaults and survive a campaign reset.

## Envelope (schema 1)

```json
{ "schema": 1, "savedAt": 1762531200000, "state": { ...GameState... } }
```

`state` is the `Codable` encoding of `GameState` (sorted keys). Notable encodings:

- `seed` and `rng` are 64-bit values stored as lowercase hexadecimal strings, so JSON never loses precision;
- dictionaries keyed by ids (`lines`, `inventory`, `districts`, `fronts`, `eventLastSeen`, `legacy.perks`, `routes`)
  are JSON objects keyed by the id's raw value (e.g. `"GLIMMER"`);
- non-finite doubles are written as `"inf"`, `"-inf"`, `"nan"` and repaired on load;
- `journal` holds the newest 60 bookings, each with a monotonic `seq`; `journalCount` is the next number.

## Writing (atomic, with backup)

1. Encode the envelope and write it to `.tmp` (`Data.write(options: .atomic)`).
2. If a primary exists **and still decodes**, it replaces the backup; a damaged primary is deleted instead, so garbage
   is never promoted to backup.
3. Move `.tmp` to the primary name.

A crash between steps leaves either the old primary or the backup, both loadable. A leftover `.tmp` is ignored.
When the save was written by a newer schema, the app never writes over it unless the player chooses "Start over".

## Loading

1. Primary decodes → load it.
2. Primary is from a newer schema → show the protected "save from a newer version" screen (nothing is overwritten).
3. Primary missing or damaged → try the backup; if it decodes, load it and tell the player ("Save recovered").
4. Neither usable → start a fresh campaign.

After decoding, `SaveCodec.sanitize` repairs anything out of range (NaN/negative money, Heat outside 0–100, levels
outside 1–10/12/14, chapter outside 0–6, unknown crew ids, duplicate roles or improvements, invalid reserve, negative
clock, oversized journal, perk ranks above their maximum), and guarantees the starter line and the Cellar Quarter are
available, so a damaged save can never crash or dead-lock the game. Every field is decoded tolerantly: a missing or
malformed field falls back to its default instead of failing the whole save.

## Migrations

`SaveCodec.migrations` maps *from-schema* → transform on the raw JSON object of `state`. Decoding a schema-N save in a
schema-M app applies N→N+1→…→M in order, then decodes with today's types; old saves never need old Swift types.
Schema 1 is the first shipped format, so the shipped registry is empty. The pipeline is proven by
`SaveTests.migrationPipeline` (a schema-1 save decoded by a schema-3 codec with two injected migrations) and
`brokenMigration` (missing or throwing migrations mark the save corrupt, which then falls back to the backup).

## Tests

`Packages/NoirCore/Tests/NoirCoreTests/SaveTests.swift` (lossless round trip incl. 64-bit RNG, future version,
corrupt inputs, sanitising, migrations, atomic store, backup recovery, interrupted write) and
`AppTests/AppTests.swift` (relaunch persistence, offline credit after relaunch, backup recovery notice, future-save
protection, reset). `UITests` terminate and relaunch the real app, corrupt the primary and check the recovery alert.
