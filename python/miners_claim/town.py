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


from .townplan import buildings, shaft


def visible_facades(camera_x: int, camera_y: int,
                    layout: str = 'frontier') -> tuple[tuple[str, pygame.Rect], ...]:
    """Visible shop fronts in world coordinates, clipped to the mine view."""
    if camera_y > 1:
        return ()
    clip = pygame.Rect(0, HUD, CANVAS_WIDTH, 144)
    result = []
    for building in buildings(layout):
        rect = pygame.Rect((building.west-camera_x)*TILE, HUD-camera_y*TILE,
                           (building.east-building.west+1)*TILE, 2*TILE)
        cropped = rect.clip(clip)
        if cropped.width and cropped.height:
            result.append((building.name, cropped))
    return tuple(result)


def _write(surface, font, text: str, x: int, y: int, color=PAPER):
    surface.blit(font.render(text, False, color), (x, y))


def _center(surface, font, text: str, cx: int, y: int, color=PAPER):
    graphic = font.render(text, False, color)
    surface.blit(graphic, (cx - graphic.get_width() // 2, y))


def draw_town(surface: pygame.Surface, camera_x: int, camera_y: int,
              font, layout: str = 'frontier', frame_number: int = 0):
    """World-aligned western buildings, east mine signs and walking locals."""
    if camera_y > 1:
        return
    surface.set_clip(pygame.Rect(0, HUD, CANVAS_WIDTH, 144))
    try:
        palette = {
            'mercantile': ('MERCANTILE', (118,80,52), (80,48,38)),
            'bank': ('BANK', (120,111,93), (64,72,78)),
            'assay': ('ASSAY OFFICE', (112,112,109), (68,76,88)),
            'saloon': ('SALOON', (141,83,65), (91,50,46)),
        }
        for b in buildings(layout):
            label, siding, roof = palette[b.name]
            x = (b.west-camera_x)*TILE
            y = HUD-camera_y*TILE
            w = (b.east-b.west+1)*TILE
            pygame.draw.rect(surface, (31,26,25), (x+2,y+6,w-4,27))
            pygame.draw.rect(surface, siding, (x+4,y+8,w-8,23))
            for wx in range(x+5, x+w-5, 9):
                pygame.draw.line(surface,tuple(max(0,c-13) for c in siding),
                                 (wx,y+13),(wx,y+28))
            pygame.draw.polygon(surface,roof,((x,y+9),(x+8,y+3),
                                              (x+w-8,y+3),(x+w,y+9)))
            pygame.draw.line(surface,(186,144,91),(x+8,y+4),(x+w-8,y+4))
            cx = x+w//2
            pygame.draw.rect(surface,(43,33,28),(cx-43,y+8,86,12))
            pygame.draw.rect(surface,(205,162,92),(cx-43,y+8,86,12),1)
            _center(surface,font,label,cx,y+10,(244,214,145))
            for window_x in (x+18,x+w-31):
                pygame.draw.rect(surface,(37,62,80),(window_x,y+21,14,10))
                pygame.draw.line(surface,(111,181,198),(window_x+2,y+22),
                                 (window_x+2,y+29))
            pygame.draw.rect(surface,(57,37,28),(cx-8,y+21,16,11))
            pygame.draw.rect(surface,(183,126,74),(cx-8,y+21,16,11),1)
            pygame.draw.circle(surface,GOLD,(cx+4,y+27),1)
        if layout == 'frontier':
            # Signposts establish west-left and east-right orientation.
            for column, caption in ((2, 'WEST'), (64, 'EAST')):
                px = (column-camera_x)*TILE
                py = HUD+(1-camera_y)*TILE
                pygame.draw.rect(surface,(90,62,36),(px+6,py-10,3,25))
                pygame.draw.rect(surface,(166,123,76),(px-10,py-14,35,10))
                _center(surface,font,caption,px+7,py-13,(32,26,22))
            sx=(shaft(layout)-camera_x)*TILE
            sy=HUD+(1-camera_y)*TILE
            _center(surface,font,'MINE',sx+8,sy-15,GOLD)
            draw_townspeople(surface, camera_x, camera_y, frame_number)
    finally:
        surface.set_clip(None)


def draw_townspeople(surface, camera_x: int, camera_y: int,
                    frame_number: int = 0):
    """Four simple, nonblocking pedestrians with different walking cycles."""
    palette = ((182,83,72),(82,152,188),(177,157,78),(133,109,168))
    for i, clothing in enumerate(palette):
        # Wrap at the town's eastern edge, always on the open surface.
        cycle = (frame_number // (7+i*2) + i*17) % 60
        world_x = 4 + (cycle if i % 2 == 0 else 59-cycle)
        px=(world_x-camera_x)*TILE+1
        py=HUD+(1-camera_y)*TILE
        if not (-18<px<CANVAS_WIDTH+10):
            continue
        stride=(frame_number//(5+i))%2
        pygame.draw.rect(surface,(44,41,47),(px+4,py+12,3,3+stride))
        pygame.draw.rect(surface,(44,41,47),(px+9,py+12,3,4-stride))
        pygame.draw.rect(surface,clothing,(px+4,py+6,9,7))
        pygame.draw.rect(surface,(220,165,121),(px+5,py+2,7,5))
        pygame.draw.rect(surface,(76,50,40),(px+4,py+1,9,2))
        pygame.draw.rect(surface,(53,43,39),(px+6,py+4,1,1))


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

def draw_bank(surface: pygame.Surface, font, large, miner,
              balance: int, amount: str):
    """Bank ledger: all transfers are performed by engine.Game."""
    surface.fill((19,23,31))
    pygame.draw.rect(surface,(61,72,79),(9,8,302,160))
    pygame.draw.rect(surface,(178,157,103),(9,8,302,160),2)
    pygame.draw.rect(surface,(32,40,49),(18,16,284,30))
    _center(surface,large,'FRONTIER BANK',160,21,GOLD)
    _center(surface,font,'SAFE DEPOSITS AND WITHDRAWALS',160,38,PAPER)
    _write(surface,font,f'POCKET CASH       ${miner.money}',29,59)
    _write(surface,font,f'BANK BALANCE      ${balance}',29,75,GOLD)
    pygame.draw.line(surface,(178,157,103),(26,94),(294,94))
    _write(surface,font,'TRANSFER AMOUNT',26,105)
    pygame.draw.rect(surface,(17,21,27),(150,101,139,19))
    pygame.draw.rect(surface,(204,173,104),(150,101,139,19),1)
    _write(surface,font,f'${amount}_',157,107,GOLD)
    _write(surface,font,'D DEPOSIT   W WITHDRAW',40,134,PAPER)
    _write(surface,font,'C CLEAR     L LEAVE',59,151,GOLD)


def draw_saloon(surface: pygame.Surface, font, large, miner):
    """Saloon menu with one-water drinks and an even-odds high-card game."""
    surface.fill((24,17,20))
    pygame.draw.rect(surface,(92,51,44),(10,8,300,160))
    pygame.draw.rect(surface,(209,151,83),(10,8,300,160),2)
    pygame.draw.rect(surface,(56,30,30),(18,16,284,34))
    _center(surface,large,'FRONTIER SALOON',160,22,GOLD)
    _center(surface,font,'DRINKS, CARDS AND CONVERSATION',160,42,PAPER)
    _write(surface,font,f'YOUR CASH: ${miner.money}',36,63,GOLD)
    _write(surface,font,'D  BUY DRINK   ${5}  (WATER +1)',27,84)
    _write(surface,font,'P  PLAY HIGH CARD   ${10} BET',27,104)
    _write(surface,font,'HIGHER CARD WINS ${10}; TIE: NO CHANGE',26,124)
    _write(surface,font,'L  RETURN TO TOWN',67,151,GOLD)
