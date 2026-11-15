# Miner's Claim v1.0.0

The first public gameplay release of **Miner's Claim**, a retro mining game created by Randall L. Morgan and preserved from its QB64 original.

## Highlights
- Playable Python / pygame-ce desktop edition with HiDPI-friendly integer scaling, resizable display, fullscreen mode and readable pixel lettering.
- Western town with Mercantile, Assay Office, Bank and Saloon; purchases, assay sales, bank deposits/withdrawals, drinks and high-card game.
- Surface townspeople, an animated wheelbarrow, cargo changes and east/west signs.
- Mining, ore collection, ladders, provisions, hazards, gas/water warnings, TNT, and random road encounters with banker and bandit.
- Reduced bandit probabilities based on playtesting, with greater risk toward the eastern mine.
- QB64 archival sources preserved, plus original-save import, native JSON saving, regression tests and CI.
- Source-only release archives in ZIP and tar.gz formats, with SHA-256 checksums.

## Install and run
Python **3.10+** and the dependency in `python/requirements.txt` are required. From the extracted repository:

```bash
cd python
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python -m miners_claim
```

Windows: activate with `.venv\\Scripts\\activate`.

For usage and controls see [Python edition README](python/README.md).

## Scope and limitations
This is a **source-code release**, not a packaged desktop executable. No Linux or Windows binary installer is included. The Python edition is playable but still undergoing incremental polish; legacy QB64 files are archival. The bank/saloon, NPC and active-hazard changes are extensions beyond QB64 v29. Existing legacy save maps remain supported.

## Licensing
Copyright © 2026 Randall L. Morgan. Distributed under the **Miner's Claim Noncommercial Share-Alike License 1.0** (MC-NSAL 1.0), a custom **source-available, non-OSI** license. See [LICENSE](LICENSE) for terms and attribution requirements.
