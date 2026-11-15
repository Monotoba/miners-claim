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

Optional: `python -m miners_claim --scale 2 --seed 12345`, or import an existing original QB64 save with `--load-qb64 /path/to/miners_claim_save.txt`.

## Controls

- At Mercantile: **1–8** purchase equipment, **L** leave.
- Mine: **arrow keys** move or dig, **J** jump, **L** place ladder, **M** enter Mercantile near town, **S** enter Assay Office, **T** drop TNT, **P** collect blasted ore.
- Assay: numeric value and **Enter** to sell, **A** to sell everything, **C** clear, **L** leave.
- **F5** save, **F9** load. **Esc** quits the current run or returns from assay.

Saves use a validated JSON format in `~/.local/share/miners-claim/miners_claim_python.json` (Windows uses the same path relative to the user's home). QB64 save V1/V2 import is supported; export back to QB64 is not yet provided.

## Differences and incomplete items

- Terrain uses a seedable Python RNG and will not match QB64 byte-for-byte.
- Graphics are simplified placeholder sprites; no sound effects yet.
- High scores are currently held only for the running session (no persistent score file).
- The original screen art and some menu messages are not reproduced verbatim.
- Rules are isolated and covered by headless tests; playable behavior still needs user playtesting.
- No Windows/Linux standalone executable packages or automated release builds yet.

To test from repo root: `python -m unittest discover -s tests -v`.