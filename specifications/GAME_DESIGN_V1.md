# Miner's Claim — Game Design and Porting Specification

**Specification version:** 1.0 (baseline extraction, 2026-11-15)  
**Reference implementation:** `original-qb64/MinersClaim_QB64_v29_simple_tnt_timer.bas`  
**Copyright:** © 2026 Randall L. Morgan  
**License:** `../LICENSE` (MC-NSAL 1.0)

## 1. Status and scope

This document describes **observed code-level behavior** of the archived QB64 v29 implementation. It is a **porting reference, not proof of correct runtime behavior**. No QB64 execution, CoCo emulator tests, or physical-hardware tests were performed to produce this specification. Where behavior seems surprising or inconsistent, it is documented rather than silently corrected. For other implementations, deviations must be deliberate, tested, and recorded in a platform difference document.

The original QB64 source is immutable historical material. Work on separate ports; do not alter archived files.

### Current expanded-game and CoCo porting requirements

This v1.0 document remains the **unchanged historical QB64 v29 behavioral baseline**. The **current Python v1.0.0 release and new CoCo target priorities** are specified in [`FEATURE_PRIORITY_COCO.md`](FEATURE_PRIORITY_COCO.md). That companion specification contains the modern-feature inventory, per-feature play-value rankings, dependency rules, platform profiles, and the explicit feature-removal sequence. When designing a new port, consult **both** documents; do not interpret original QB64 facts in this baseline as requirements to include every feature in every CoCo edition.


## 2. Core gameplay loop

Player purchases equipment at the Mercantile, moves along the surface to the CLAIM shaft, digs or mines underground tiles, gathers value into a limited haul, returns to the Assay Office to exchange haul for cash, and repeats. Hazards consume lives. The win condition is **cash (not cash plus unsold haul) >= $1,000,000**. Runs end through quitting, life exhaustion, or a bankruptcy check; results may be recorded in the top-ten high scores.

## 3. World and display

| Setting | QB64 v29 value |
| --- | --- |
| Logical screen | 320 × 200 pixels |
| Display scaling | 6× (1920 × 1200 window) |
| Target update rate | 30 iterations/second (`_LIMIT 30`) |
| Tile size | 16 × 16 pixels |
| World | 128 columns × 96 rows, indexed from zero |
| Top of grass | `SURFACE_Y = 2` |
| Claim shaft | `x = 28`, ladder extends from `y=1` through `y=9` |
| Starter room | x=25..32, y=7..9 (after carving); later deposits overwrite selected tiles |
| HUD / message bar | 24 / 16 logical pixels |
| Visible mine viewport | 320 × 160 logical pixels |
| Starting position | `(8, 1)` |
| Starting lives / money | 5 / $150 |

Tile enumerations: `AIR=0`, `GRASS=1`, `DIRT1=2`, `DIRT2=3`, `DIRT3=4`, `ROCK=5`, `GOLD=6`, `SILVER=7`, `GEM=8`, `WATER=9`, `GAS=10`, `SAND=11`, `SNAKE=12`, `LADDER=13`, `BEDROCK=14`.

Base terrain by y: air for y<2; grass at 2; dirt1 for 3..17; dirt2 for 18..37; dirt3 for 38..57; rock for 58..93; bedrock for 94..95. Random ore/hazards and 120 randomly stamped circular patches overwrite terrain; a fixed starter claim, ladder, safe area, and guaranteed deposits are applied last. The source uses QB64 `RND` and `RANDOMIZE TIMER`; **identical maps across programming languages are not required in v1**, since their RNG sequences differ. Preserve terrain layering, probabilities/order, safety guarantees, and data bounds; seedable generators are recommended for future testability.

The initial starter area near the claim entrance is cleared of water, gas, snakes, and sand; guaranteed first- and second-underground-row ore exists next to the ladder. See `AddStarterDeposits` for exact coordinates.

## 4. Character state and movement

Player fields: `x`, `y`, `lives`, `money`, `food`, `water`, `ladders`, boolean `shovel`, `pickaxe`, `wheelbarrow`, `lantern`, integer `tnt`, `haul`, `steps`, `deepest`.

- Arrow keys move one tile horizontally or vertically. Horizontal input takes priority when both horizontal and vertical keys are held. A movement attempt has a 4-loop delay.
- Air and ladders are traversable; all other tiles require an applicable dig interaction (or block movement).
- Moving upward through air requires a ladder in the current or destination tile, unless already at or above grass row `y=2`. `J` jumps up one passable tile if supported; it supplies 18 gravity-update loops of grace.
- A lantern is mandatory to enter a row **greater than `SURFACE_Y + 2`**, i.e. y>=5.
- When unsupported and in the mine state, gravity attempts to move the miner down one tile on each update; gravity moves increase steps and depth but, as written, **do not call** `ConsumeProvisions`.
- The surface walking and grass rows y=1 and y=2 always count as supported, even if material is dug away underneath. A ladder on the current tile or non-air directly below also counts as support.
- Player-initiated `MoveMiner` increments `steps`, updates `deepest` and calls `ConsumeProvisions`.
- Provision checks apply only underground (y>2): on step multiples of 60, one water is consumed, otherwise one life is lost; on multiples of 100, one food is consumed, otherwise one life is lost. At multiples of both, water is checked first and failure exits before food.

### Digging and hazards

| Target tile | Requirement | Result |
| --- | --- | --- |
| Grass or dirt | Shovel | Replace tile with air and move into it |
| Rock | Pickaxe | Replace tile with air and move into it |
| Gold, silver, gem | Pickaxe + sufficient haul capacity | Add value, clear tile, move into it |
| Sand | Shovel | 25% collapse (`RND < .25`) causes life loss; otherwise clear and enter |
| Water, gas, snake | None | Clear tile and lose life |
| Bedrock | Not mineable | Remain in place |
| Ladder | None | Move into it |

After nonterminal death, lose all carried haul and respawn at `(8,1)`; purchased equipment and money remain. A death that reduces lives to zero transitions to name entry. The bankruptcy condition is specific: money<=0, haul<=0, food<=0, water<=0, shovel=0, pickaxe=0. Other equipment is **not** considered by this check.

## 5. Economy

At the Mercantile, keys 1–8 buy:

| Key | Item | Price | Effect |
| --- | --- | ---: | --- |
| 1 | Shovel | $10 | One-time tool |
| 2 | Pickaxe | $15 | One-time tool |
| 3 | Wheelbarrow | $30 | Increases haul capacity |
| 4 | Ladder | $20 | +1 placeable ladder |
| 5 | Food | $5 | +1 ration |
| 6 | Water | $5 | +1 canteen |
| 7 | Lantern | $10 | One-time light |
| 8 | TNT | $25 | +1 stick |

Haul capacity is **$75** without a wheelbarrow, **$300** with one. Ore values: gold **$20**, silver **$12**, gem **$45** per tile. The Assay Office converts any positive sale value, capped at remaining haul, to cash 1:1; `A` sells all. An empty, zero or negative sale is rejected. Sale entry accepts up to six decimal digits.

The Mercantile interaction zone is `x=0..12, y<=6`; the Assay Office zone is `x=10..25, y<=6` (the player must press its interaction key). No special check prevents interaction while underground if these coordinates are satisfied.

## 6. TNT and loose ore

- `T` drops a single charge at the miner's current tile; requires TNT inventory, no already-active charge, and y>2. One stick is consumed.
- Fuse: **300 updates** at nominal 30 updates/second (approximately 10 seconds of active game-loop time). The fuse decrements in the **store, mine, and assay** states, but not in other states. A saved game preserves fuse frames.
- Blast radius: Euclidean squared distance <=25 (radius 5 tiles).
- Surface rows y<=2, bedrock, and out-of-bounds tiles are protected.
- If the player is within blast radius at detonation, `LoseLife` runs and the function returns **before terrain is cleared**. Therefore a fatal/nearby blast does *not* excavate terrain or create loot in v29.
- Otherwise, affected unprotected tiles become air; valuables are converted to `LooseLoot[x,y]`, preserving their dollar value. `P` gathers loose value within the miner's 3×3 neighborhood up to capacity; uncollected value remains in the world.

## 7. Controls and screens

Startup loads the high-score table, initializes a new game, and displays High Scores. In High Scores: `N` or Enter starts a new run; `L`/`O` loads; `Q` quits. Store: digits 1..8 buy; `L` enters mine; `V` saves; `O` loads; `Q` ends the run via name entry. Mine: arrows move/dig, `J` jump, `L` ladder, `T` TNT, `P` pick up blast loot, `M` store, `S` assay, `V` save, `O` load, `Q` abandon. Assay: decimal digits, Enter sell amount, `A` sell all, `C` clear, `L`/`M`/Esc exit. Winner and game-over/name-entry/high-score states have distinct key handlers; inspect source when reproducing every input transition.

The source creates graphics with QB64 drawing primitives and uses QB64 `SOUND`; no external images/audio are required.

## 8. Saving and high scores

`miners_claim_save.txt` is a line-oriented QB64 text file with magic `MINERS_CLAIM_SAVE_V2`; the reader also accepts `MINERS_CLAIM_SAVE_V1` (without TNT/loose-loot data). Following the magic are **15** miner scalar values in this order: x, y, lives, money, food, water, ladders, shovel, pickaxe, wheelbarrow, lantern, tnt, haul, steps, deepest. V2 adds **4** TNT values: active, x, y, fuse frames. Then 12,288 world tile integers in **row-major y then x** order, then 12,288 loose-loot values in the same order. Loading sets state to Mine. The loader checks only the magic and basic TNT-frame clamps; it does **not** provide comprehensive corruption/bounds validation.

`miners_claim_scores.txt` starts with `MINERS_CLAIM_SCORES_V1`, then up to 10 triplets (name, score, depth), one value per line. Name is limited to 12 characters. Score on run exit is **cash + unsold haul**; depth in feet is `max(0, (deepest - 2) × 10)`. Equal scores are inserted before existing equal scores. The $1 million win condition, by contrast, uses cash alone.

Port recommendations: retain import/export support for historical saves where feasible, while adopting a validated, versioned, atomic native-save format. QB64 text parsing and random-number behavior must be tested against known samples rather than assumed portable.

## 9. Porting requirements and differences

**Shared invariants:** tile taxonomy, starting resources, tool costs, ore values, carrying capacity, state transitions, life-loss rules, victory predicate, TNT behavior (including its early return on blast injury), and starter-deposit guarantees. Any change to original behavior must be marked as an **intentional deviation** with a regression test.

**Python desktop:** pygame-ce; retain behavior first, then optional settings, scalable rendering, input remapping, modern save integrity. Packaged builds must run without QB64 or a user-installed Python runtime.

**Web:** JavaScript/TypeScript with HTML Canvas; no server required for core game play. Browser persistence needs explicit format/version and import/export tests. Clearly provide source access and license attribution under MC-NSAL.

**CoCo 1:** 6809-targeted implementation with stringent memory and graphics budgets; evaluate 32 KB baseline, 16 KB only if feasible. **CoCo 2:** leverage 64 KB where present but note it largely shares legacy graphics capabilities with CoCo 1; memory/CPU tradeoffs should be measured. **CoCo 3:** separate GIME graphics support and 128 KB/512 KB targets. Native disk images and emulator testing are required; real hardware compatibility is not yet established. A faithful 128×96 tile world may require storage streaming, compression, or procedural regeneration, and no specific approach is approved yet.

## 10. Baseline verification cases

See [`../tests/test_spec_baseline.py`](../tests/test_spec_baseline.py) for static checks against original source constants and preserved source integrity. These tests are **not** gameplay runtime tests. Target behavior tests for each port should include:

1. Starting state `(8,1)`, $150, five lives, empty inventory, $75 haul limit.
2. Buying each item deducts the listed price; repeat purchase of one-time tools is refused.
3. Correct shovel/pickaxe requirements; ore collection capacity blocks oversized deposits without consuming them.
4. No descent below y=4 without a lantern; upward climb restrictions; jump only from support; surface walkway stability.
5. Water on every 60th player step and food on every 100th underground player step, including intersection and gravity behavior.
6. Hazard response and life/haul loss; terminal game and bankruptcy predicates.
7. TNT only underground, one active fuse, 300 updates, protected tiles, five-tile circular blast, player within radius short-circuit behavior, 3×3 loot pickup with partial remainder.
8. Assay partial/all sale; money-only $1,000,000 victory; cash-plus-haul score on exit.
9. Save V1/V2 read, V2 write, bad magic rejection, high-score sorting/tie behavior, naming limit.
10. Generated starter shaft/guaranteed deposits and absence of water/gas/snake/sand in the specified safe zone.

## 11. Known caveats / follow-up investigation

- QB64's `RND`, frame scheduling, sound, keyboard buffering, and integer/overflow semantics may differ from modern languages.
- `ApplyGravity` does not consume provisions; clarify whether future ports preserve the behavior or fix it through a documented game-design revision.
- Saving is non-atomic; malformed save files may raise runtime errors. Modern ports should be robust against corrupted files without changing legacy import semantics silently.
- The `LoseLife` routine preserves equipment but resets haul; TNT death returns before excavation. Confirm that these are intended gameplay rules before altering them.
- Some user-facing prose in the code is not a tested specification. Record discrepancies during playtesting rather than guessing intended behavior.
- Licensing provisions are custom, non-OSI and separate from hardware/software compatibility; obtain independent legal review as appropriate.
