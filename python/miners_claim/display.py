"""Pure window-layout helpers for the fixed 320x200 game canvas.

No pygame dependency: layout behavior is tested on headless CI.
"""
from __future__ import annotations


def choose_scale(desktop: tuple[int, int], logical: tuple[int, int] = (320, 200),
                 max_scale: int = 8, margin: int = 96) -> int:
    """Choose the largest integer zoom that fits within the desktop with headroom."""
    dw, dh = desktop
    lw, lh = logical
    if min(dw, dh, lw, lh) <= 0:
        raise ValueError("Display dimensions must be positive")
    return max(1, min(max_scale, (max(1, dw-margin)) // lw,
                      (max(1, dh-margin)) // lh))


def viewport(window: tuple[int, int],
             logical: tuple[int, int] = (320, 200)) -> tuple[int, int, int, int]:
    """Return centered integer-pixel viewport without distortion or clipping.

    Integer nearest-neighbor zoom is preferred, with proportional downscaling
    for windows smaller than the logical game canvas.
    """
    ww, wh = window
    lw, lh = logical
    if min(ww, wh, lw, lh) <= 0:
        raise ValueError("Display dimensions must be positive")
    factor = min(ww / lw, wh / lh)
    if factor >= 1:
        factor = int(factor)
    width = max(1, min(ww, int(lw * factor)))
    height = max(1, min(wh, int(lh * factor)))
    return ((ww-width)//2, (wh-height)//2, width, height)
