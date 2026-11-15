# Miner's Claim

[![CI](https://github.com/Monotoba/miners-claim/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Monotoba/miners-claim/actions/workflows/ci.yml)
[![License: MC-NSAL 1.0](https://img.shields.io/badge/license-MC--NSAL%201.0-blue)](LICENSE)
![Project status: QB64 archival baseline](https://img.shields.io/badge/status-QB64%20archive-informational)
[![Latest release](https://img.shields.io/github/v/release/Monotoba/miners-claim?display_name=tag&label=release)](https://github.com/Monotoba/miners-claim/releases)

**Miner's Claim** is a retro-style, side-scrolling mining game originally written in QB64.

Copyright © 2026 Randall L. Morgan.

## Status

The original QB64 source is archived here without modification. The native CoCo 1, CoCo 2, CoCo 3, Python and JavaScript versions are planned; **they are not implemented** in this repository.

## Original code

- `original-qb64/MinersClaim_QB64.bas` — initial recovered prototype (June 12, 2026)
- `original-qb64/MinersClaim_QB64_v23_tnt_fuse_blast.bas` — historical snapshot (June 12, 2026)
- `original-qb64/MinersClaim_QB64_v29_simple_tnt_timer.bas` — latest recovered snapshot (June 13, 2026)

These are separate historical files, not a verified sequential Git development history. The project has not yet undergone runtime QA or hardware testing.

## Playing / building

Install a compatible QB64 implementation and open `original-qb64/MinersClaim_QB64_v29_simple_tnt_timer.bas`. Compile and run within QB64. The source describes controls and includes no required external art or sound files.

## Game design specification

The [QB64 v29 gameplay baseline](specifications/GAME_DESIGN_V1.md) documents implemented mechanics, values, persistence formats, porting requirements, and outstanding ambiguities. Its source-derived static checks can be run with:

```bash
python3 -m unittest discover -s tests -v
```

Static tests do not validate QB64 runtime execution or CoCo hardware compatibility.

## Continuous integration and releases

The [GitHub Actions CI workflow](.github/workflows/ci.yml) checks archived QB64 source integrity and source-derived specification assertions on Linux and Windows using Python 3.10 and 3.13. It runs on pushes to `main`, pull requests, and manual dispatch.

When a tag matching `v*` is pushed, **after all CI test jobs pass**, the workflow creates a GitHub Release containing source-only ZIP and tar.gz archives plus a `SHA256SUMS` manifest. It does not yet compile QB64 or package playable Python, JavaScript, or CoCo binaries; those release jobs will be added as the respective implementations mature.

No external secrets are required; the release job receives narrowly scoped `contents: write` permission, while test jobs have read-only permissions.

## Roadmap

1. Establish versioned gameplay specifications and test scenarios.
2. Port to Python for Linux and Windows, preserving gameplay.
3. Port to JavaScript for browsers.
4. Implement 6809-based CoCo 1/2 and CoCo 3 editions, with documented platform differences.

## License

Covered by the custom **Miner's Claim Noncommercial Share-Alike License 1.0** in [LICENSE](LICENSE). Commercial use requires separate written permission from the relevant copyright holder(s). This is **source-available**, not OSI-approved open source.

Attribution requirements apply to redistributed and derivative versions. See [ATTRIBUTION.md](ATTRIBUTION.md).

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a contribution. A contributor rights agreement will be developed before contributions are accepted for possible commercial relicensing.
