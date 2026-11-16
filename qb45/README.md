# Miner's Claim — Microsoft QuickBASIC 4.5 / DOS edition

**Status:** initial source port **v0.1.0**, not yet compiled or playtested with the actual Microsoft QuickBASIC 4.5 compiler. This is a separate DOS port, *not* the existing QB64 program renamed. The archived QB64 v29, QB64 v0.3.0, and Python v1.0.0 files remain unchanged.

## Requirements and starting the game

- Microsoft **QuickBASIC 4.5** (`QB.EXE`) for MS-DOS, or its compiler (`BC.EXE` and linker). Neither the compiler nor its copyrighted runtime is included.
- VGA-compatible display or emulator supporting `SCREEN 13` (320×200, 256 colors).
- DOS, FreeDOS, DOSBox, DOSBox-X or a similarly compatible emulator.
- Conventional-memory budget sufficient for a compiled QuickBASIC program (not yet measured on hardware).

Copy `MINER45.BAS` into a DOS-accessible directory using the 8.3 filename. In DOSBox with a mounted `C:` drive containing `QB.EXE` and the source, enter:

```text
C:
CD \MINER45
QB MINER45.BAS
```

Inside the QuickBASIC IDE choose **Run → Start** (normally Shift+F5). To compile to an `.EXE`, use QuickBASIC's **Run → Make EXE File** (or BC and LINK from the installed toolchain). Run as `MINER45.EXE` from the directory containing your saves. The source-only candidate has not yet been certified to compile under the real MS compiler: report any line-numbered compiler diagnostics so they can be fixed without changing the Python/QB64 games.

**On Linux:** The `~/apps/qb64-lnx/qb64` executable used for the QB64 edition is *not* Microsoft QuickBASIC 4.5. Use QuickBASIC within DOSBox/FreeDOS; do not treat successful QB64 compilation as QB4.5 compatibility proof.

## Controls

| Screen | Keys | Description |
| --- | --- | --- |
| Opening | `N`, `O`, `Q` | Start, load DOS save, quit |
| Mercantile | `1`–`8`, `L` | Buy shovel $10, pickaxe $15, cart $30, ladder $20, food $5, water $5, lantern $10, TNT $25; leave |
| Mine/town | Arrows; `J`, `L`, `M`, `S`, `B`, `N` | Move/dig; jump; place ladder; enter Mercantile/Assay/Bank/Saloon when near that business |
| Mine | `T`, `P`, `V`, `O`, `Q` | TNT; pick up blast loot; save/load; abandon claim |
| Assay | Digits, Enter, `A`, `C`, `L` | Sell amount or all; clear entry; leave |
| Bank | Digits, `D`, `W`, `C`, `L` | Deposit/withdraw; clear; leave |
| Saloon | `D`, `P`, `L` | Drink $5 (+1 water), $10 high-card wager, leave |
| Encounter | Enter/Space/Esc | Resume movement after banker/bandit interruption |
| End | `N`/`R`, `Q` | Restart or quit |

## Feature coverage and deliberate differences

The **128×96** world, values ($20 gold, $12 silver, $45 gems), starting $150 and 5 lives, mine shaft at x=72, shop/assay/bank/saloon positions, ore-carrying limits ($75/$300), provisions, jump/ladder/lantern mechanics, TNT and blast loot, banker and bandit eligibility, bank-aware $1 million victory, and optional timed gas/water proximity hazard are carried over conceptually from the QB64/Python editions. The bank balance remains immune to theft. The 24-step bandit cooldown and low east-weighted robbery rate are retained.

For genuine 16-bit DOS compatibility, the visual presentation is deliberately simpler: `SCREEN 13`, 8×8 tiles, 40 columns and 25 text rows, compact 2-row HUD, compact storefronts, a fixed wheelbarrow/cargo indicator. Animated walking NPCs, score-table persistence, high-resolution textures, scalable windowing and QB64 sound are deferred. The mine stays 128×96 by using per-row byte strings; a separate map stores loose-ore dollar values as single bytes. This keeps *world data* near 24 KiB instead of two large INTEGER arrays, but actual compiled memory requirements still need measurement. TNT loot per cell is capped at 255 DOS-map dollars (normally deposits produce at most $45 per cell).

**Saves:** this version uses `MC45SAVE.DAT` (a versioned native ASCII/hex format headed `MC45V1`) in the DOS working directory. The map is 96 rows of 128 hex digits and the loose-ore map 96 rows of 256 hex digits. It intentionally does not overwrite or parse QB64 V1/V2/V3 saves; conversion can be implemented as an offline utility later. Transient exposure, pending TNT fuse and encounter cooldown are reset on load. Copy important save files before testing this candidate.

**Performance:** graphics refresh on input or state changes rather than redrawing every frame. Water/gas timers and TNT fuse use `TIMER`; behavior depends on DOS timer resolution. DOS keyboards deliver arrows as extended key codes (`CHR$(0)` + a scan code). Gameplay timings, screen geometry, and DOSBox keyboard autorepeat need actual testing. There are no external graphics or sound dependencies.

## Verification and limitations

Run portable static checks from the repository root:

```bash
python -m unittest discover -s tests -p 'test_qb45_port.py' -v
```

Static tests verify the absence of QB64-only syntax, declaration/block consistency, basic design constants, game loop, save headers, tile/loot layout, and the 25-row VGA layout. **They do not certify that Microsoft QB4.5 compiles the source or that the game runs correctly.** Do not publish this as a verified DOS binary until an actual QB4.5 compilation and full gameplay round-trip succeed.

Recommended manual test sequence: open the title; buy shovel/pickaxe/lantern; travel to shaft x=72; descend and mine guaranteed deposits; return and sell; deposit/withdraw; save and reload; buy TNT and test blast/pickup; exercise hazards; ensure the final text row is visible; test bankruptcy and victory with a controlled test build.

## Licensing

Copyright © 2026 Randall L. Morgan. This port follows the repository's [Miner's Claim Noncommercial Share-Alike License 1.0](../LICENSE), a custom source-available, non-OSI license.