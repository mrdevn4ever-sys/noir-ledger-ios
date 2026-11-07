# Save format, migration and recovery

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
