"""Pixel-art Mercantile and Assay Office for the original 320x200 canvas.

Presentation only. Trade rules and interaction boundaries remain in engine.Game.
All geometry uses logical coordinates so existing integer/HiDPI zoom works.
"""
from __future__ import annotations

import pygame

TILE = 16
HUD = 24
CANVAS_WIDTH = 320
CANVAS_HEIGHT = 200
SHOP_LEFT, SHOP_RIGHT = 0, 12
ASSAY_LEFT, ASSAY_RIGHT = 13, 25
GOLD = (242, 202, 109)
PAPER = (231, 218, 183)
MUTED = (157, 151, 139)
INK = (18, 17, 23)
WOOD = (104, 68, 46)
WOOD_LIGHT = (151, 103, 61)


def visible_facades(camera_x: int, camera_y: int) -> tuple[tuple[str, pygame.Rect], ...]:
    """Return visible world-aligned shop fronts, clipped to the mine viewport."""
    if camera_y > 1:
        return ()
    clip = pygame.Rect(0, HUD, CANVAS_WIDTH, 160)
    facades = []
    for name, left, right in (
        ('mercantile', SHOP_LEFT, SHOP_RIGHT),
        ('assay', ASSAY_LEFT, ASSAY_RIGHT),
    ):
        rect = pygame.Rect((left-camera_x)*TILE, HUD-camera_y*TILE,
                           (right-left+1)*TILE, 2*TILE)
        cropped = rect.clip(clip)
        if cropped.width and cropped.height:
            facades.append((name, cropped))
    return tuple(facades)


def _write(surface, font, text: str, x: int, y: int, color=PAPER):
    surface.blit(font.render(text, False, color), (x, y))


def _center(surface, font, text: str, cx: int, y: int, color=PAPER):
    graphic = font.render(text, False, color)
    surface.blit(graphic, (cx - graphic.get_width() // 2, y))


def draw_town(surface: pygame.Surface, camera_x: int, camera_y: int,
              font: pygame.font.Font):
    """Draw town buildings *over* the world tiles and *under* the miner."""
    if camera_y > 1:
        return
    surface.set_clip(pygame.Rect(0, HUD, CANVAS_WIDTH, 160))
    try:
        for label, left, right, siding, roof in (
            ('MERCANTILE', SHOP_LEFT, SHOP_RIGHT, (118, 80, 52), (80, 48, 38)),
            ('ASSAY OFFICE', ASSAY_LEFT, ASSAY_RIGHT, (112, 112, 109), (68, 76, 88)),
        ):
            x = (left-camera_x)*TILE
            y = HUD-camera_y*TILE
            w = (right-left+1)*TILE
            # Low silhouette fits within the two sky rows available in v29.
            pygame.draw.rect(surface, (31, 26, 25), (x+2, y+6, w-4, 27))
            pygame.draw.rect(surface, siding, (x+4, y+8, w-8, 23))
            for wx in range(x+5, x+w-5, 9):
                pygame.draw.line(surface, tuple(max(0, c-13) for c in siding),
                                 (wx, y+13), (wx, y+28))
            pygame.draw.polygon(surface, roof, ((x, y+9), (x+8, y+3),
                                                 (x+w-8, y+3), (x+w, y+9)))
            pygame.draw.line(surface, (186, 144, 91), (x+8, y+4), (x+w-8, y+4), 1)
            cx = x+w//2
            pygame.draw.rect(surface, (43, 33, 28), (cx-43, y+8, 86, 12))
            pygame.draw.rect(surface, (205, 162, 92), (cx-43, y+8, 86, 12), 1)
            _center(surface, font, label, cx, y+10, (244, 214, 145))
            for window_x in (x+18, x+w-31):
                pygame.draw.rect(surface, (37, 62, 80), (window_x, y+21, 14, 10))
                pygame.draw.line(surface, (111, 181, 198), (window_x+2, y+22),
                                 (window_x+2, y+29))
            pygame.draw.rect(surface, (57, 37, 28), (cx-8, y+21, 16, 11))
            pygame.draw.rect(surface, (183, 126, 74), (cx-8, y+21, 16, 11), 1)
            pygame.draw.circle(surface, GOLD, (cx+4, y+27), 1)
    finally:
        surface.set_clip(None)


def draw_store(surface: pygame.Surface, font: pygame.font.Font,
               large: pygame.font.Font, miner, prices: dict[str, int]):
    """Presentation of existing purchases; game.buy() remains the authority."""
    surface.fill((20, 18, 23))
    pygame.draw.rect(surface, (64, 43, 31), (7, 7, 306, 174))
    pygame.draw.rect(surface, (159, 113, 72), (7, 7, 306, 174), 2)
    pygame.draw.rect(surface, (36, 28, 27), (14, 13, 292, 25))
    _center(surface, large, 'MERCANTILE', 160, 16, GOLD)
    _center(surface, font, 'MINING SUPPLIES', 160, 29, MUTED)
    _write(surface, font, f'CASH  ${miner.money}', 19, 44, GOLD)
    _write(surface, font, 'ITEM                 COST  STOCK', 19, 56, MUTED)
    pygame.draw.line(surface, WOOD_LIGHT, (18, 69), (302, 69))
    for i, (item, price) in enumerate(prices.items()):
        y = 72 + i*12
        pygame.draw.rect(surface, (77, 53, 40) if i % 2 == 0 else (67, 47, 37),
                         (16, y, 288, 12))
        available = getattr(miner, item)
        stock = ('OWNED' if available else '--') if item in ('shovel','pickaxe','wheelbarrow','lantern') else str(available)
        _write(surface, font, f'{i+1}', 20, y+1, GOLD)
        _write(surface, font, item.replace('_',' ').upper(), 38, y+1)
        _write(surface, font, f'${price}', 198, y+1, PAPER if miner.money >= price else (225, 127, 115))
        _write(surface, font, stock, 250, y+1, (148, 220, 152) if stock == 'OWNED' else PAPER)
    # Last item sits at y=156; footer is above the 16px global message bar.
    _write(surface, font, '1-8 BUY    L LEAVE     F5 SAVE', 19, 171, GOLD)


def draw_assay(surface: pygame.Surface, font: pygame.font.Font,
               large: pygame.font.Font, miner, sale_input: str):
    """Presentation of existing cash-for-haul exchange; game.sell() validates."""
    surface.fill((19, 21, 27))
    pygame.draw.rect(surface, (57, 61, 66), (11, 9, 298, 173))
    pygame.draw.rect(surface, (173, 160, 118), (11, 9, 298, 173), 2)
    pygame.draw.rect(surface, (35, 38, 44), (19, 16, 282, 30))
    _center(surface, large, 'ASSAY OFFICE', 160, 20, GOLD)
    _center(surface, font, 'ORE EXCHANGE', 160, 35, MUTED)
    _write(surface, font, 'WE BUY GOLD, SILVER & GEMSTONES', 30, 54)
    pygame.draw.line(surface, (166, 151, 104), (26, 69), (294, 69))
    pygame.draw.rect(surface, (31, 37, 43), (25, 77, 270, 41))
    _write(surface, font, f'UNSOLD HAUL   ${miner.haul}', 35, 82, GOLD)
    _write(surface, font, f'CASH ON HAND  ${miner.money}', 35, 99, PAPER)
    _write(surface, font, 'SALE AMOUNT', 32, 124, MUTED)
    pygame.draw.rect(surface, (12, 16, 22), (126, 122, 166, 18))
    pygame.draw.rect(surface, (182, 157, 95), (126, 122, 166, 18), 1)
    _write(surface, font, f'${sale_input}_', 135, 126, GOLD)
    _write(surface, font, 'ENTER SELL    A SELL ALL    C CLEAR', 29, 150)
    _write(surface, font, 'L / ESC  RETURN TO CLAIM', 65, 166, GOLD)