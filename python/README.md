# Miner's Claim — Python desktop edition (initial playable port)

An initial playable port of the QB64 v29 gameplay with Python 3.10+ and pygame-ce. The rules engine is independent of Pygame and uses only the standard library. The project uses the root LICENSE, MC-NSAL 1.0, Copyright © 2026 Randall L. Morgan.

## Run on Linux or Windows

```bash
cd python
python -m venv .venv
. .venv/bin/activate        # Linux; Windows: .venv\\Scripts\\activate
python -m pip install -r requirements.txt
python -m miners_claim
```

The UI uses a bundled, original 5×7 pixel font for clear numerals, currency symbols, and labels at integer display scales.

The default is **automatic integer zoom** chosen to fit the current desktop. The game window is **resizable**, with centered letterboxing so the original 320×200 proportions are maintained. Press **F11** to toggle fullscreen. You can specify a fixed starting scale using `--scale 1` through `--scale 8`, or start fullscreen using `--fullscreen`.

Optional: `python -m miners_claim --scale 4 --seed 12345`, or import an original QB64 save with `--load-qb64 /path/to/miners_claim_save.txt`. Display layout is calculated from the SDL-reported desktop dimensions; OS-specific high-DPI scaling can vary, especially on fractional-scaling setups.

## Controls

- At Mercantile: **1–8** purchase equipment; the screen displays cash, item prices, inventory, and which durable tools are already owned. **L** leaves.
- Mine: **arrow keys** move or dig, **J** jump, **L** place ladder, **M** enter the **Mercantile** (near x=0–12, y≤6), **S** enter the **Assay Office** (near x=10–25, y≤6), **T** drop TNT, **P** collect blasted ore. Surface storefronts and context prompts indicate the shops. The interaction zones intentionally overlap at x=10–12 as they did in the original game.
- Assay: enter a numeric value and press **Enter** to sell, **A** to sell everything, **C** clear, **L** or **Esc** leave. The screen shows cash and unsold haul.
- **F5** save, **F9** load. **Esc** quits the current run or returns from assay.

## Context legend and active hazards

The bottom of the screen now has **two separate lines**: a contextual legend identifying nearby ore, equipment controls, or hazards, and the current gameplay message. The mine viewport is nine tiles tall rather than ten to reserve space for the footer; original world coordinates and saving are unchanged.

This Python version deliberately extends the original static hazard rules:

- **Gas** is toxic when the miner is in an open cell directly adjacent to a gas pocket. A warning begins, and remaining there for 20 game updates (about 0.67 seconds at 30 FPS) costs a life.
- **Water** similarly threatens an adjacent miner after 35 updates (about 1.17 seconds). Falling into or moving directly into water or gas costs a life immediately, and the pocket remains hazardous.
- Leaving the exposed area resets accumulated exposure. Hazards do **not yet simulate physically flowing water or expanding gas clouds**; these changes implement contact and leakage-zone danger without altering the save format. Current exposure warnings do not persist across loading a game.

### Wheelbarrow cargo trips

The wheelbarrow is now drawn on the surface whenever the miner owns it, including when empty. The **visible cargo** changes automatically:

- Leaving the **Mercantile after purchasing supplies** shows food, provisions, or tool packages in the wheelbarrow. Leaving without buying anything shows an empty barrow.
- Once the miner travels **underground**, the packages remain with the mine's supplies and are no longer drawn in the cart. This is visual staging; purchased items remain in the player's inventory and are not deleted.
- Returning to the surface **with mined ore** loads ore into the wheelbarrow; nothing other than ore is shown being brought out of the mine.
- Entering the **Assay Office** unloads the wheelbarrow. It remains visually empty afterward, whether the miner sells all or only part of the haul. Any unsold value remains available in the gameplay engine for subsequent Assay Office visits, rather than reappearing in the cart immediately.
- A subsequent trip underground and back can fill the cart with ore again.

Cart contents are **presentation-only, not a new inventory type**, and are not serialized into the save file. The movement, ore values, inventory, and purchasing/selling mechanics are unchanged. The wheelbarrow retains a small step-based wheel/cargo animation.


Saves use a validated JSON format in `~/.local/share/miners-claim/miners_claim_python.json` (Windows uses the same path relative to the user's home). QB64 save V1/V2 import is supported; export back to QB64 is not yet provided.

## Differences and incomplete items

- Terrain uses a seedable Python RNG and will not match QB64 byte-for-byte.
- Graphics now include surface Mercantile and Assay Office buildings, redesigned trading interiors, procedural pixel-art textures, and a more detailed miner, without external image assets. Town buildings are visual overlays on the original world (no terrain/save-file changes). Artwork is still provisional; no sound effects yet.
- High scores are currently held only for the running session (no persistent score file).
- The original screen art and some menu messages are not reproduced verbatim.
- Rules are isolated and covered by headless tests. Window sizing and letterboxing have additional unit tests. Player testing has confirmed the earlier game runs; the latest font, hazard and cart changes require additional desktop playtesting.
- No Windows/Linux standalone executable packages or automated release builds yet.

To test from repo root: `python -m unittest discover -s tests -v`. CI runs the engine, layout, archive-integrity, and headless pygame smoke tests on Linux and Windows.