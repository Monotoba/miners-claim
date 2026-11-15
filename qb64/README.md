# Miner's Claim — QB64 v0.3.0 port

**Status:** source implementation, awaiting compilation and interactive gameplay
verification in QB64-PE. This is a separate **QB64 edition version**; the
Python edition retains its own v1.0.0 tag. The historical QB64 v29 sources in
`original-qb64/` are unmodified.

## Quick start

Open `MinersClaim_QB64_v0.3.0.bas` in QB64-PE, compile, and run. It uses QB64
image, keyboard, and audio extensions; it is **not** intended for QuickBASIC
4.5 or the Color Computer. The 320×200 game scales 6× by default; edit
`SCREEN_SCALE` for a smaller window if needed. No external artwork is required.

### Implemented mechanics

- 128×96 world, $150 starting cash, five lives, equipment, ore values,
  carrying capacity, lantern, ladders, gravity, provisions, TNT and pickup.
- Frontier town oriented **west (left)** to **east (right)**: separate Mercantile
  x=1–11, Bank x=15–23, Assay x=27–37, Saloon x=41–53, mine shaft x=72.
- `M` Mercantile (keys 1–8), `S` Assay (amount+Enter / `A` all), `B` Bank
  (amount then `D` deposit / `W` withdraw), `N` Saloon (`D` $5 drink adds one
  water, `P` $10 high card), `L` to exit menus.
- Four nonblocking, animated surface pedestrians and visible, animated
  wheelbarrow with supply parcels, ore, or empty state.
- Banker encounter at ≥$300 pocket cash, 1.2% per eligible surface step,
  encouraging a bank deposit; bandit can take all ore or all pocket cash
  (> $300), but not both. Bank funds and equipment are safe. The bandit
  probability is `0.00005 + 0.00045 * (x / 72)^2` per eligible east–west
  surface movement, with 24-step encounter cooldown. `Enter`, `Space` or
  `Esc` acknowledges the encounter.
- Contact with water/gas costs a life, and nearby water/gas causes a timed
  warning (35/20 game updates respectively). Pocket tiles persist.
- Victory and final score include bank funds; transferred bank cash is not
  counted twice. Legacy saves retain their historic town layout.

### Saving and loading

`V` saves to `miners_claim_qb64_v030_save.txt` in the current working folder,
using **MINERS_CLAIM_SAVE_V3**, retaining all old miner/TNT/world/loose-ore
fields and appending the bank balance and town-layout flag before the map.
`O` loads this file; if it is absent, it attempts the old `miners_claim_save.txt`
V1/V2 file. Loading an old save retains its historical x=28 shaft and two
shopfronts. Save files are not compatible for *writing* to old QB64 v29;
keep backups. Like the historical loader, this source does not yet provide
comprehensive malformed-file handling.

### Validation

Run static regression tests from repository root:

```bash
python -m unittest discover -s tests -p 'test_qb64_port_v030.py' -v
```

These tests verify structural invariants, code paths, economic transfers,
and versioned save layout. **They do not compile, execute, or certify QB64.**
Before publishing as a final tagged executable release, compile in QB64-PE,
play a full mining round trip, test all bank/saloon/encounter and cart states,
verify old save imports, and run the full Python regression suite.

## Legal

Copyright © 2026 Randall L. Morgan. MC-NSAL 1.0 (custom, non-OSI license).
See repository `LICENSE`.