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
- Mine: **arrow keys** move or dig, **J** jump, **L** place ladder, **M** enter the Mercantile, **B** enter the Bank, **S** enter the Assay Office, **N** enter the Saloon, **T** drop TNT, **P** collect blasted ore. On newer maps the buildings have separate, nonoverlapping frontages; imported legacy saves retain the original shop areas.
- Assay: enter a numeric value and press **Enter** to sell, **A** to sell everything, **C** clear, **L** or **Esc** leave. The screen shows cash and unsold haul.
- **F5** save, **F9** load. **Esc** quits the current run or returns from assay.

## Frontier town: West and East

**New games** use a spaced western town (Mercantile, Bank, Assay Office and Saloon), followed by an open stretch to the mine shaft **east at world column 72**. Four townspeople wander along the surface; they are decorative and cannot block the player. On the surface, the context legend displays west/east directions and building keys.

- **Mercantile:** Stand within its frontage and press **M** to purchase the existing eight supplies.
- **Bank:** Press **B**, type an amount, then **D** to deposit or **W** to withdraw. **C** clears the amount and **L** leaves. Depositing/withdrawing is a transfer, never a profit; balances remain available after saving and loading.
- **Assay Office:** Press **S** and sell all or part of the mined ore as before.
- **Saloon:** Press **N** to enter; **D** buys a **$5 drink** (adds one water provision); **P** plays one hand of **high-card for $10**, drawing a rank for the miner and the house. Higher rank wins $10 net; lower rank loses $10; ties do not change the cash balance. The two cards are displayed. **L** returns to town. These are in-game dollars only.

The engine now counts **cash in hand plus deposited bank funds** toward the $1,000,000 victory target and final score (plus unsold ore for score). This is an intentional change to original QB64 cash-only victory, preventing deposits from making progress disappear. The Assay Office still pays only into cash in hand.

**Older Python saves** lacking `town_layout`, and imported original QB64 saves, retain their *legacy* shop placement and the original shaft at x=28. Such games do not have bank or saloon access. New saves include optional `town_layout` and `bank_balance` fields while retaining the `miners-claim-python-v1` identifier; old saved games remain readable. Saloon card display and walking NPC positions are not saved.

## Random encounters on the west–east road

In **new frontier games**, moving horizontally along the surface between the western town and the eastern mine can trigger an NPC encounter. Movement pauses until **Enter**, **Space**, or **Esc** acknowledges the conversation. Encounters cannot happen underground, inside shops, or on imported legacy layouts. After an encounter, 24 more surface steps pass without another encounter.

- **Bank adviser:** When carrying **$300 or more in cash**, the miner has a 1.2% chance per eligible surface step (after the bandit check) of being stopped and encouraged to deposit money at the bank. This encounter never takes cash.
- **Bandit:** If the miner carries **any unsold ore** or **more than $300 cash**, a bandit can rob the miner. The chance per eligible surface step rises with the west–east position: **0.3% at x=0**, increasing quadratically to **2.3% near the mine at x=72**. The bandit takes **all ore or all pocket cash**, choosing randomly when both are eligible, but never both during the same encounter. The miner keeps equipment, provisions, lives, and bank deposits. The wheelbarrow's ore drawing updates automatically when the ore is stolen.

These are intentionally probabilistic *game mechanics* that extend the original QB64 version, and the probabilities can be adjusted after playtesting. Saving is available again after the encounter is dismissed; the cooldown is transient and not persisted.

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
- Graphics now include four separated western town buildings, a larger distance to the eastern mine, animated townspeople, redesigned interiors and playing cards, procedural pixel-art textures, and a more detailed miner, without external image assets. Town buildings are visual overlays on the original world (no terrain/save-file changes). Artwork is still provisional; no sound effects yet.
- High scores are currently held only for the running session (no persistent score file).
- The original screen art and some menu messages are not reproduced verbatim.
- Rules are isolated and covered by headless tests. Window sizing and letterboxing have additional unit tests. Player testing has confirmed the earlier game runs; the latest font, hazard and cart changes require additional desktop playtesting.
- No Windows/Linux standalone executable packages or automated release builds yet.

To test from repo root: `python -m unittest discover -s tests -v`. CI runs the engine, layout, archive-integrity, and headless pygame smoke tests on Linux and Windows.