"""Frontier town layout and historic save compatibility.

Town destinations are indexed in world tiles. Buildings are decorative:
they do not block movement on the surface. Archive saves retain the
original, tightly spaced shop positions and shaft at x=28.
"""
from __future__ import annotations

from dataclasses import dataclass

@dataclass(frozen=True)
class Building:
    name: str
    west: int
    east: int

FRONTIER_BUILDINGS = (
    Building('mercantile', 1, 11),
    Building('bank', 15, 23),
    Building('assay', 27, 37),
    Building('saloon', 41, 53),
)
LEGACY_BUILDINGS = (
    Building('mercantile', 0, 12),
    Building('assay', 13, 25),
)
FRONTIER_SHAFT = 72
LEGACY_SHAFT = 28
FRONTIER_START = (8, 1)

def buildings(layout: str = 'frontier') -> tuple[Building, ...]:
    return LEGACY_BUILDINGS if layout == 'legacy' else FRONTIER_BUILDINGS

def near(layout: str, name: str, x: int, y: int) -> bool:
    # Original code allowed entering Mercantile 0..12 and Assay 10..25.
    if y > 6 or y < 0:
        return False
    if layout == 'legacy':
        if name == 'mercantile':
            return 0 <= x <= 12
        if name == 'assay':
            return 10 <= x <= 25
        return False
    return any(b.name == name and b.west <= x <= b.east
               for b in FRONTIER_BUILDINGS)

def shaft(layout: str = 'frontier') -> int:
    return LEGACY_SHAFT if layout == 'legacy' else FRONTIER_SHAFT
