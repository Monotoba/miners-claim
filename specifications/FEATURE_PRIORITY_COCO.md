# Miner's Claim — Feature Priorities and CoCo Porting Profile

**Design specification:** 1.1 — November 15, 2026  
**Reference playable edition:** Python/Pygame v1.0.0, tag `v1.0.0` (`f6ea88a0`)  
**Historical baseline:** [GAME_DESIGN_V1.md](GAME_DESIGN_V1.md), QB64 v29 (unchanged source semantics)  
**Status:** proposed porting policy; not an assertion that CoCo code or hardware has been tested  
**License:** MC-NSAL 1.0; © 2026 Randall L. Morgan

## 1. Objective and acceptance rule

Produce a recognizably playable Miner's Claim on the CoCo 1, 2, and 3 without carrying over desktop-only presentation and optional side activities at the expense of the mining loop.

**Minimum playable core:** buy tools → travel to mine → dig ore → obey carrying limits → survive a hazard → return → sell ore → repeat toward a goal. The player must be able to lose, restart, see money/haul/lives and identify tiles. A full play cycle must work with no bank, saloon, NPCs, wheelbarrow *animation*, TNT, or bandits.

Do not confuse *optional mechanics* with the rules required by retained mechanics. For example, a wheelbarrow's **capacity bonus** is important, but its animated cart is optional; a bank is optional, but if enabled, bank funds must be counted in victory and protected from robbery. **No option may silently leave a dead control, inaccessible menu, broken win condition, or incompatible save.**

### Definitions

- **P0 / mandatory:** Required for the playable core; do not cut. Simplify the implementation, not the behavior.
- **P1 / high:** Strongly recommended for gameplay character, balance or safe operation. Omit only if measurements justify it.
- **P2 / medium:** Material gameplay depth or usability, but core works without it.
- **P3 / low:** Atmosphere, embellishment, secondary economy and quality-of-life extras.
- **P4 / last:** Desktop-specific decoration, compatibility conveniences or high-cost presentation with negligible effect on mining.
- **Drop order:** Remove **P4 → P3 → P2 → P1** as a *budget-driven* decision, never P0. Rows within a priority are ordered by drop number; the larger the drop number, the earlier to remove. Priority reflects importance to playing, **not implementation difficulty**.

## 2. Ranked feature inventory

`B` = historical QB64 baseline; `E` = gameplay extension in the Python v1.0.0 edition; `V` = presentation layer. “Minimal implementation” is the intended CoCo fallback. Numbers are **unique, ordered retention ranks**, where **1 is hardest to remove** and **higher numbers are removed first**.

| Keep rank | Priority | Feature | Origin | Minimum retained behavior / reason | CoCo reduction option |
| ---: | :---: | --- | :---: | --- | --- |
| 1 | **P0** | Walk/dig/excavate and bounds | B | Tile movement; shovel vs pickaxe; obstacle rules | Character/tile graphics |
| 2 | **P0** | World terrain and starter claim | B | Dirt/rock/ores, safe initial shaft and reachable deposits | Smaller streamed or regenerated mine; test density |
| 3 | **P0** | Ore value and collection | B | Gold $20, silver $12, gem $45; no unearned ore | Distinct characters/colors rather than sprites |
| 4 | **P0** | Mine/store/assay state transitions | B | Leave merchant, reach mine, exchange ore | Text screens; compact town with explicit prompts |
| 5 | **P0** | Money, purchases and essential tools | B | Initial $150; shovel $10, pickaxe $15; money deducted | Minimal item menu |
| 6 | **P0** | Haul limit, return and sale | B | $75 baseline, $300 with wheelbarrow; 1:1 sale | Numeric ledger; no animated cargo |
| 7 | **P0** | Lives, death, restart, end/win | B | Five starting lives; losing haul on death; $1m economic target or explicitly scaled port target | Short end screen, no leaderboard |
| 8 | **P0** | Clear HUD, basic controls and item identity | B/V | See location, cash, haul, lives, tile types and commands | Text status; fixed glyph tiles |
| 9 | **P0** | Core hazard/difficulty consequence | B | At least dangerous water/gas/snake or equivalent, sand risk, survival/life loss | Simple immediate contact rules; no timed proximity |
| 10 | **P0** | Gravity, ladders/climbing and lantern limits | B | Reach lower layers and return; do not trap player | Simplified gravity frame timing but deterministic rules |
| 11 | **P1** | Consumable food/water survival | B | Underground resource management; baseline 60/100 step intervals | Keep counters; coarse notices |
| 12 | **P1** | Wheelbarrow capacity upgrade | B | Purchased capacity changes from $75 to $300 | Inventory flag, no cart sprite |
| 13 | **P1** | Starter mine safety, depth scaling | B | Feasible early play; progressively tougher/deeper digging | Fewer terrain classes but maintain challenge |
| 14 | **P1** | Resume/save game | B/E | Long mining sessions can be resumed | Compact versioned disk/cassette save if feasible; otherwise label as unsupported |
| 15 | **P1** | Functional town navigation and directions | E/V | Find Mercantile, Assay and mine reliably | Two labeled entrances and a shaft, not four storefronts |
| 16 | **P1** | Safe state transitions + input debouncing | B/E | No accidental repeated buys or movement; no interrupted menu state | Single-keystroke menus and frame/step limiter |
| 17 | **P2** | TNT and circular excavation | B | Strategic shortcut, risk/reward | Optional; if present preserve safety and capacity tests |
| 18 | **P2** | Blast-generated loose ore and pickup | B | Required *only if TNT is retained* | Can simplify blast radius; never destroy ore values silently |
| 19 | **P2** | Water/gas proximity exposure and warnings | E | Fair reaction time beyond baseline contact death | Contact-only if timing/CPU tight |
| 20 | **P2** | Separate gold/silver/gem visual cues | V | Easy distinction at a glance | ASCII symbols or 2-color patterns |
| 21 | **P2** | Readable context-sensitive legend | E/V | Discovers nearby hazards/controls | One changing text line; no full footer panel |
| 22 | **P2** | Full 128×96 world and exact terrain variety | B | Exploration scope beyond a smaller playable world | Compress, stream, or reduce size with a documented difference |
| 23 | **P2** | Bank deposits/withdrawals | E | Protect cash, create planning choice | Optional ledger and single menu screen |
| 24 | **P2** | Bank-aware scoring and victory | E | Mandatory *when bank retained*; cash+bank to win, score adds haul | Remove together with bank; revert to baseline cash-only win |
| 25 | **P2** | Bandit robbery and east-weighted risk | E | Town-to-mine risk/reward; balance as tuned in Python | Optional one-line encounter; no animation |
| 26 | **P2** | Bandit-bank protection and encounter cooldown | E | Mandatory *if bandits exist*: only carried ore or cash>300 lost; bank untouched | Fixed chance by zone; no NPC display |
| 27 | **P3** | Expanded west-to-east town spacing | E | Atmosphere and travel sense | Compress to short main street |
| 28 | **P3** | Friendly bank adviser | E | Suggest bank when holding ≥$300 cash | Optional one-line message; remove with bank |
| 29 | **P3** | Saloon drinks (+1 water, $5) | E | Alternative water vendor | Remove if saloon not included |
| 30 | **P3** | Saloon high-card ($10 bet) | E | Optional side activity; no effect on mining rules | Remove before drinks |
| 31 | **P3** | High-score table/name entry | B | Replay incentive | Score display only |
| 32 | **P3** | Detailed storefront/interior art | V | Flavor | Static text labels and borders |
| 33 | **P3** | Animated pedestrian town NPCs | E/V | Atmosphere, nonblocking | Omit entirely |
| 34 | **P3** | Animated wheelbarrow with empty/supplies/ore states | E/V | Visual feedback only; not inventory | Show inventory count or one fixed icon |
| 35 | **P4** | Full desktop 320×200 viewport and letterboxing | B/V | Not native CoCo display requirement | Use native video mode with responsive text/tile sizes |
| 36 | **P4** | HiDPI scale, resizable window, F11 | E/V | Desktop display features | Omit on CoCo |
| 37 | **P4** | Multi-shade procedural texture and decorative sprites | E/V | Visual polish | Monochrome/limited palette tile glyphs |
| 38 | **P4** | Advanced high-card drawing artwork and animation | E/V | Optional visual embellishment | Simple numerical card ranks if game remains |
| 39 | **P4** | QB64 text-save import in the CoCo runtime | E | Migration convenience, not required to play | Offline conversion on a PC instead |
| 40 | **P4** | Original desktop UI pixel matching, effects and sound | B/V | Nostalgia only | Basic tones, or silence |

**Dependency override:** a low-ranked item may be mandatory **within** an included higher-ranked feature. E.g., TNT without collecting its blasted ore is not an acceptable “simplified TNT” unless a new tested reward rule is specified. The retention ranking is a design recommendation; individual ranks can be revised after actual memory/frame-time measurements.

## 3. Feature profiles by port

| Scope | CoCo 1 minimal target | CoCo 2 enhanced target | CoCo 3 target |
| --- | --- | --- | --- |
| **Required** | All P0, suitably simplified | All P0 | All P0 |
| **Strong preference** | P1 only as memory/storage permits | All P1 where feasible | All P1 |
| **Optional gameplay** | P2 selectively: TNT or bank only after profiling | P2 as measured; prioritize TNT and hazards | Most P2 if performance permits |
| **Atmosphere** | P3 omitted first | Selected P3, minimal street artwork | Selected/most P3 |
| **Desktop-only** | P4 omitted | P4 omitted | CoCo-specific improvements instead of P4 |
| **Presentation** | Text/tile display, compact HUD, simple colors | Similar CoCo 1 video modes with more memory as available | GIME-aware tile/graphics modes; extra detail where measurable |
| **Memory assumptions** | Evaluate 32 KB as design target, not proven minimum | Target 64 KB when installed; 32 KB optional evaluation | Evaluate 128 KB baseline, 512 KB enhancements |
| **World** | Memory-budgeted chunks/compression/regeneration | More retained map/chunks | Large/full map if viable |
| **Save** | Prefer disk; tape/save support investigated, not promised | Versioned disk save targeted | Versioned disk save targeted |

CoCo 1/2 video capabilities are not identical to modern desktop modes; do not assume the 320×200 Python canvas can be used unchanged. The 128×96 map has **12,288 cells**. At a packed 4 bits per tile, the base map alone costs **6,144 bytes**, before loot, player state, display buffers, code, stack or platform storage overhead. A separate one-byte-per-tile loose-ore array would cost another 12,288 bytes. These are **planning estimates**, not a measured implementation. Choose memory layout only after emulator profiling and checking actual RAM available under the OS/ROM/video setup.

## 4. Explicit removal sequence under resource pressure

This is the **default order** to remove functionality after verifying playable P0:

1. **Presentation/desktop extras:** HiDPI/windowing, decorative textures, animated card artwork, desktop pixel matching and effects (ranks 35–40).
2. **Atmosphere:** wheelbarrow animation, walking townspeople, elaborate facades, high-score entry, high-card game, saloon drinks, bank adviser, long main street (ranks 27–34, from highest rank downward).
3. **Optional economic risk:** bandit encounters and their bank interaction, or the bank itself; preserve any dependency still enabled (ranks 23–26).
4. **Optional deep mechanics:** full world dimensions, context footer, extended mineral cues, gas/water proximity effects, TNT loose-ore system and TNT (ranks 17–22; remove dependent pieces together).
5. **Only after measurement:** selected P1 conveniences; never remove an indispensable way to buy, dig, carry, sell, return, lose or win.

Suggested CoCo 1 **first milestone**: skip the bank, saloon, adviser, bandit, pedestrians, decorative cart and TNT; implement a compact Mercantile, mine and Assay Office, a smaller world, core hazards, the essential equipment and a full repeatable mining trip. Add P1 and P2 items in subsequent builds based on memory and responsiveness.

## 5. Behavioral differences to preserve or decide explicitly

| Behavior | QB64 v29 historical baseline | Python v1.0.0 frontier implementation | Port decision |
| --- | --- | --- | --- |
| Shaft / town | Shaft x=28; adjacent store/assay zones overlap | Shaft x=72; separate Mercantile, Bank, Assay and Saloon; old saves retain x=28 layout | Compact or expanded, documented |
| Victory / score | Win: cash ≥$1m; score: cash+haul | Win: cash+bank ≥$1m; score: cash+bank+haul | Cash-only if bank omitted; cash+bank if present |
| Water/gas | Entering clears hazard and costs a life | Contact harms; adjacent exposed gas/water causes timed danger (20/35 updates) | Minimum contact; adjacency optional |
| TNT | 300-frame fuse, radius five; loose ore | Similar engine semantics, no requirement for fancy blast art | TNT and pickup optional together |
| Saloon | Not present | $5 drink -> +1 water; $10 high-card | Optional |
| Bank | Not present | Deposits/withdrawals, persisted `bank_balance` | Optional; deposit only funds in hand |
| Bank adviser | Not present | If cash ≥$300, 1.2% chance per eligible surface step after bandit check | Optional; never alters balance |
| Bandit | Not present | If haul>0 or cash>$300, steals **all of one eligible category**; chance `0.00005 + 0.00045*(x/72)^2` per eligible step, x=0..72; 24-step cooldown after encounter | Optional; never bank funds |
| Wheelbarrow | Capacity flag only | Capacity plus transient visible cargo: supplies outbound, ore inbound, empty after Assay | Keep capacity; animation optional |
| Town NPCs | Not present | Four animated, nonblocking surface walkers | Optional |
| Saves | QB64 V1/V2 lines; score table file | Native JSON `miners-claim-python-v1`, legacy QB64 import; optional `town_layout` / `bank_balance`; transient encounter/cart state not saved | Distinct platform versioned format + tests |
| High scores | Persistent top ten | Session-only scores in current Python application | Optional on memory-constrained ports |

**Important Python nuances:** the bank adviser threshold is **cash ≥$300**, whereas the bandit's cash eligibility is **cash >$300**; unsold ore is eligible at any positive value. The bandit does *not* take all holdings—only one eligible category (all ore or all pocket cash). Event probability is per **eligible horizontal surface movement**, not per video frame. The bank and saloon are **not available to legacy-layout saves**.

## 6. Scope decisions and acceptance tests for each CoCo build

Before implementing a target, create a checked-in `COCO_<target>_PROFILE.md` or equivalent platform-difference document with a chosen map size, minimum RAM, video mode, P0/P1/P2 set, cut features, measured available heap/stack/video budget, and disk/tape strategy. Do not mark a target playable based solely on compilation.

Required **P0 acceptance checks**, run in emulator first and on real hardware when available:

1. New game establishes spawn, five lives, $150, initial tools/haul and reachable shaft; no inaccessible starter deposits.
2. Buy shovel/pickaxe; cash decrements exactly, repeat purchases of durable tools are rejected.
3. Move/dig with correct tool requirements; mine each valuable ore, respect haul limit and block over-capacity excavation.
4. Return via ladder/shaft without becoming trapped; gravity, jump, darkness, life loss and respawn behave as documented.
5. Sell ore in Assay; update cash and clear sold haul; repeat a complete mine-to-town loop.
6. Trigger hazard and life loss with proper haul forfeiture, including game-over and restart.
7. Reach win state through a deterministic test configuration; if a bank exists, verify bank-aware score/win calculations and no creation/destruction of funds by transfer.
8. Confirm all commands fit the native display and no text becomes unreadable or clipped; measure frame responsiveness.
9. Validate bounds, terrain generation and map safety against out-of-range tiles with representative seeds.
10. If save is included, round-trip a game with altered world/haul state; reject damaged or mismatched files gracefully.

Feature-specific regression tests are mandatory for any optional system that is included: TNT blast + loose pickup; bank transfer invariants; high-card bankroll logic; exact adviser/bandit thresholds and eastward risk; cart-state visuals; or proximity danger timing. Test all code changes and commit coherent patches to the local Git repository with descriptive messages.

## 7. Evidence and revision discipline

This document is based on the archived QB64 spec and the checked-in Python v1.0.0 code/tests. It does **not** claim that CoCo hardware, disk I/O, frame rate, compression or sound requirements have been measured. The CoCo profiles are starting recommendations, not final architecture approvals.

Change priorities in a new reviewed commit, record the impact on the minimal playable core, and keep the QB64 historical specification authoritative for original behavior. **Do not alter the original `.bas` archives to make new features agree with them.**
