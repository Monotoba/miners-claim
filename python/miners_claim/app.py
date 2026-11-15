"""Pygame UI for the Miner's Claim Python port."""
from __future__ import annotations
import argparse
from pathlib import Path
import pygame
from .display import choose_scale, viewport
from .town import draw_town, draw_store, draw_assay, draw_bank, draw_saloon
from .bitmapfont import PixelFont
from .context import legend, WheelbarrowCargo
from .engine import (Game, WIDTH, HEIGHT, TILE, AIR, GRASS, DIRT1, DIRT2, DIRT3,
                     ROCK, GOLD, SILVER, GEM, WATER, GAS, SAND, SNAKE, LADDER, BEDROCK, PRICES)

SW, SH, HUD, MSG, SCALE, FPS = 320, 200, 24, 32, 3, 30
COLORS = {
    AIR:(15,13,23), GRASS:(70,120,38), DIRT1:(104,71,43),
    DIRT2:(88,59,42), DIRT3:(77,49,48), ROCK:(79,83,92),
    GOLD:(211,169,38), SILVER:(170,190,208), GEM:(90,213,193),
    WATER:(46,91,194), GAS:(99,147,65), SAND:(190,154,95),
    SNAKE:(139,58,58), LADDER:(181,120,52), BEDROCK:(35,39,47),
}
SAVE_NAME='miners_claim_python.json'


def draw_text(surface, font, s, x, y, color=(230,230,215)):
    surface.blit(font.render(s, False, color), (x,y))


def draw_terrain(surface, tile, px, py, x, y):
    """Draw a textured tile using deterministic marks, without image assets."""
    rect = pygame.Rect(px, py, TILE, TILE)
    color = COLORS[tile]
    pygame.draw.rect(surface, color, rect)
    if tile == AIR:
        return
    shadow = tuple(max(0, c - 28) for c in color)
    highlight = tuple(min(255, c + 22) for c in color)
    if tile not in (LADDER, WATER, GAS, SNAKE):
        pygame.draw.line(surface, highlight, (px, py), (px+14, py))
        pygame.draw.line(surface, shadow, (px+15, py+1), (px+15, py+15))
        pygame.draw.line(surface, shadow, (px, py+15), (px+15, py+15))
    seed = (x * 137 + y * 271) & 0xFFFF
    if tile in (DIRT1, DIRT2, DIRT3, ROCK, BEDROCK, SAND):
        for i in range(3):
            sx = px + 2 + ((seed + 7*i) % 12)
            sy = py + 2 + ((seed//7 + 11*i) % 12)
            pygame.draw.line(surface, highlight if i == 0 else shadow,
                             (sx, sy), (sx + (2 if tile == ROCK else 1), sy))
    if tile in (GOLD, SILVER, GEM):
        for ox, oy, radius in ((5, 5, 3), (10, 10, 3), (12, 4, 2)):
            pygame.draw.circle(surface, shadow, (px+ox+1,py+oy+1), radius)
            pygame.draw.circle(surface, highlight, (px+ox,py+oy), radius)
        if tile == GEM:
            pygame.draw.line(surface,(235,255,255),(px+5,py+3),(px+9,py+8),1)
    elif tile == GRASS:
        pygame.draw.line(surface,(102,170,69),(px,py+2),(px+15,py+2),2)
        for ox in (2,6,12):
            pygame.draw.line(surface,(151,192,72),(px+ox,py+3),(px+ox-1,py-1),1)
    elif tile == LADDER:
        for ox in (4,12):
            pygame.draw.line(surface,(95,58,28),(px+ox,py),(px+ox,py+15),2)
        for oy in (3,8,13):
            pygame.draw.line(surface,(245,187,95),(px+4,py+oy),(px+12,py+oy),2)
    elif tile == WATER:
        for oy in (4,10):
            pygame.draw.line(surface,(96,183,250),(px+1,py+oy),(px+7,py+oy),1)
            pygame.draw.line(surface,(69,142,229),(px+8,py+oy+2),(px+14,py+oy+2),1)
    elif tile == GAS:
        pygame.draw.circle(surface,(175,213,107),(px+7,py+7),5,1)
        pygame.draw.circle(surface,(196,235,131),(px+11,py+4),2,1)
    elif tile == SNAKE:
        pygame.draw.arc(surface,(241,183,106),(px+2,py+3,12,10),0,5,2)
        pygame.draw.circle(surface,(243,221,122),(px+11,py+5),2)
        pygame.draw.circle(surface,(30,24,19),(px+12,py+4),1)


def draw_miner(surface, px, py, moving=False):
    """Retro miner silhouette with helmet, lamp, face, and overalls."""
    pygame.draw.rect(surface,(42,41,51),(px+4,py+13,4,3))
    pygame.draw.rect(surface,(42,41,51),(px+10,py+13,4,3))
    pygame.draw.rect(surface,(55,115,179),(px+4,py+8,10,6))
    pygame.draw.rect(surface,(244,196,146),(px+5,py+4,8,6))
    pygame.draw.rect(surface,(117,75,34),(px+4,py+4,2,5))
    pygame.draw.rect(surface,(249,204,57),(px+3,py+2,12,3))
    pygame.draw.rect(surface,(200,148,29),(px+5,py,8,3))
    pygame.draw.circle(surface,(255,251,183),(px+11,py+2),2)
    pygame.draw.rect(surface,(42,37,36),(px+11,py+6,1,1))


def draw_wheelbarrow(surface, px, py, facing, steps, cargo='ore'):
    """Draw an empty, supply-loaded, or ore-loaded wheelbarrow."""
    direction = -1 if facing < 0 else 1
    cx = px - 10 if direction < 0 else px + 26
    wobble = steps % 2
    wheel_x, wheel_y = cx + direction * 4, py + 14
    pygame.draw.circle(surface, (33, 36, 43), (wheel_x, wheel_y), 4)
    pygame.draw.circle(surface, (191, 181, 155), (wheel_x, wheel_y), 2)
    pygame.draw.line(surface, (232, 223, 190), (wheel_x-2, wheel_y),
                     (wheel_x+2, wheel_y), 1)
    tray = pygame.Rect(cx-7, py+6-wobble, 14, 6)
    pygame.draw.polygon(surface, (107, 110, 116), (
        tray.topleft, tray.topright, (tray.right-3, tray.bottom),
        (tray.left+3, tray.bottom)))
    pygame.draw.line(surface, (209, 200, 177), tray.topleft, tray.topright)
    if cargo == 'ore':
        for ox, oy in ((-4,5),(0,3),(4,5)):
            pygame.draw.circle(surface, (220, 185, 51),
                               (cx+ox,py+oy-wobble), 2)
    elif cargo == 'supplies':
        # Provisions and boxed mining supplies, never represented as ore.
        pygame.draw.rect(surface, (161, 108, 66),
                         (cx-6,py+1-wobble,7,5))
        pygame.draw.line(surface, (218, 171, 91),
                         (cx-5,py+2-wobble),(cx-1,py+2-wobble))
        pygame.draw.rect(surface, (78, 134, 170),
                         (cx+1,py+2-wobble,5,4))
        pygame.draw.rect(surface, (232, 203, 118),
                         (cx-2,py-1-wobble,3,3))
    pygame.draw.line(surface, (113, 76, 44), (cx,py+8),
                     (px+8+direction*5,py+9), 2)
    pygame.draw.line(surface, (248, 197, 143), (px+8,py+8),
                     (px+8+direction*5,py+9), 2)


def main(argv=None):
    parser=argparse.ArgumentParser(description="Miner's Claim (Python edition)")
    parser.add_argument('--scale', choices=['auto', *map(str, range(1, 9))], default='auto',
                        help='Initial window scale (auto or 1..8, default: auto)')
    parser.add_argument('--fullscreen',action='store_true',help='Start in fullscreen mode')
    parser.add_argument('--seed',type=int,default=None)
    parser.add_argument('--load-qb64',type=Path,help='Import original QB64 V1/V2 save')
    args=parser.parse_args(argv)
    pygame.init()
    desktops = pygame.display.get_desktop_sizes()
    desktop = desktops[0] if desktops else (1280, 800)
    scale = choose_scale(desktop, (SW, SH)) if args.scale == 'auto' else int(args.scale)
    window_size = (SW * scale, SH * scale)
    fullscreen = args.fullscreen
    surface = pygame.display.set_mode((0, 0), pygame.FULLSCREEN) if fullscreen else pygame.display.set_mode(window_size, pygame.RESIZABLE)
    pygame.display.set_caption("Miner's Claim — Python Edition | F11 Fullscreen")
    frame=pygame.Surface((SW,SH))
    font=PixelFont(scale=1)
    large=PixelFont(scale=2)
    clock=pygame.time.Clock()
    save_path=Path.home()/'.local'/'share'/'miners-claim'/SAVE_NAME
    game=Game.import_qb64(args.load_qb64) if args.load_qb64 else Game(seed=args.seed)
    sale_input='';bank_input='';name_input='';scores=[];move_delay=0
    camera_x=camera_y=0
    facing=-1
    cart=WheelbarrowCargo()
    frame_number=0
    running=True
    while running:
        for event in pygame.event.get():
            if event.type==pygame.QUIT: running=False; continue
            if event.type!=pygame.KEYDOWN: continue
            key=event.key
            if key==pygame.K_F11:
                if fullscreen:
                    fullscreen = False
                    surface = pygame.display.set_mode(window_size, pygame.RESIZABLE)
                else:
                    window_size = pygame.display.get_surface().get_size()
                    fullscreen = True
                    surface = pygame.display.set_mode((0, 0), pygame.FULLSCREEN)
                continue
            if key==pygame.K_ESCAPE:
                if game.state in ('assay','bank','saloon'): game.state='mine'
                elif game.state in ('mine','store'): game._end_run('You abandoned the claim.')
                else: running=False
                continue
            if game.state=='store':
                if pygame.K_1<=key<=pygame.K_8:
                    cart.purchased(game.buy(list(PRICES)[key-pygame.K_1]))
                elif key==pygame.K_l:
                    game.state='mine'
                    cart.left_mercantile(game.miner)
            elif game.state=='mine':
                if key==pygame.K_j: game.jump()
                elif key==pygame.K_l: game.ladder()
                elif key==pygame.K_t: game.drop_tnt()
                elif key==pygame.K_p: game.pickup()
                elif key==pygame.K_m: game.enter_store()
                elif key==pygame.K_s:
                    if game.enter_assay():
                        cart.entered_assay()
                        sale_input=''
                elif key==pygame.K_b:
                    if game.enter_bank(): bank_input=''
                elif key==pygame.K_n:
                    game.enter_saloon()
            elif game.state=='assay':
                if pygame.K_0<=key<=pygame.K_9 and len(sale_input)<6:
                    sale_input+=chr(key)
                elif key==pygame.K_BACKSPACE: sale_input=sale_input[:-1]
                elif key==pygame.K_RETURN and sale_input:
                    game.sell(int(sale_input));sale_input=''
                elif key==pygame.K_a: game.sell(game.miner.haul);sale_input=''
                elif key==pygame.K_c: sale_input=''
                elif key in (pygame.K_l,pygame.K_m): game.state='mine'
            elif game.state=='bank':
                if pygame.K_0<=key<=pygame.K_9 and len(bank_input)<8:
                    bank_input+=chr(key)
                elif key==pygame.K_BACKSPACE:
                    bank_input=bank_input[:-1]
                elif key==pygame.K_c:
                    bank_input=''
                elif key==pygame.K_d and bank_input:
                    game.deposit(int(bank_input));bank_input=''
                elif key==pygame.K_w and bank_input:
                    game.withdraw(int(bank_input));bank_input=''
                elif key==pygame.K_l:
                    game.state='mine'
            elif game.state=='saloon':
                if key==pygame.K_d:
                    game.buy_drink()
                elif key==pygame.K_p:
                    game.play_cards()
                elif key==pygame.K_l:
                    game.state='mine'
            elif game.state in ('nameentry','winner'):
                if key==pygame.K_RETURN:
                    scores.append((name_input.strip()[:12] or 'MINER',game.final_score or game.miner.money+game.miner.haul,game.final_depth or game.depth_feet))
                    scores.sort(key=lambda row:row[1],reverse=True);scores=scores[:10]
                    game=Game();cart=WheelbarrowCargo();name_input='';game.state='store'
                elif key==pygame.K_BACKSPACE: name_input=name_input[:-1]
                elif event.unicode.isprintable() and len(name_input)<12: name_input+=event.unicode
            if key==pygame.K_F5 and game.state in ('mine','store','assay','bank','saloon'):
                try: game.save(save_path);game.message=f'Saved to {save_path}'
                except OSError as ex: game.message=f'Save failed: {ex}'
            if key==pygame.K_F9:
                try:
                    game=Game.load(save_path)
                    cart=WheelbarrowCargo()
                    game.message='Saved game loaded.'
                except (OSError,ValueError,KeyError,TypeError) as ex: game.message=f'Load failed: {ex}'

        if move_delay: move_delay-=1
        if game.state=='mine' and move_delay==0:
            keys=pygame.key.get_pressed()
            dx= -1 if keys[pygame.K_LEFT] else 1 if keys[pygame.K_RIGHT] else 0
            dy= -1 if keys[pygame.K_UP] else 1 if keys[pygame.K_DOWN] else 0
            if dx or dy:
                moved=game.try_move(dx,0) if dx else game.try_move(0,dy)
                if moved and dx:
                    facing=dx
                move_delay=4
        game.tick()
        frame_number+=1
        cart.update(game.miner)
        frame.fill((15,13,23))
        m=game.miner
        if game.state=='mine':
            # Fixed-size logical viewport, draw only visible tiles.
            camera_x=max(0,min(WIDTH-20,m.x-10))
            camera_y=max(0,min(HEIGHT-9,m.y-4))
            for sy in range(9):
                y=sy+camera_y
                for sx in range(20):
                    x=sx+camera_x;t=game.world[y][x]
                    px,py=sx*TILE,HUD+sy*TILE
                    draw_terrain(frame, t, px, py, x, y)
                    if game.loot[y][x]:
                        pygame.draw.circle(frame,(252,232,130),(px+11,py+11),3)
                        pygame.draw.circle(frame,(255,255,211),(px+10,py+10),1)
            # Buildings occupy only the first two sky rows; draw above terrain,
            # then draw the player in the foreground so doors never hide the miner.
            draw_town(frame, camera_x, camera_y, font, game.town_layout, frame_number)
            px=(m.x-camera_x)*TILE;py=HUD+(m.y-camera_y)*TILE
            draw_miner(frame, px, py)
            if cart.should_draw(m):
                draw_wheelbarrow(frame, px, py, facing, m.steps, cart.cargo)
            if game.tnt_active:
                x=(game.tnt_x-camera_x)*TILE+8;y=HUD+(game.tnt_y-camera_y)*TILE+7
                if 0<=x<SW and HUD<=y<SH-MSG:
                    pygame.draw.circle(frame,(240,65,42),(x,y),5)
            pygame.draw.rect(frame,(42,35,25),(0,0,SW,HUD))
            draw_text(frame,font,f'${m.money} BANK ${game.bank_balance} HAUL ${m.haul}/{game.capacity} LIFE {m.lives}',3,2)
            draw_text(frame,font,f'F{m.food} W{m.water} L{m.ladders} TNT{m.tnt}  Tools:{"S" if m.shovel else "-"}{"P" if m.pickaxe else "-"}{"Lan" if m.lantern else ""}',3,13)
        elif game.state=='store':
            draw_store(frame, font, large, m, PRICES)
        elif game.state=='assay':
            draw_assay(frame, font, large, m, sale_input)
        elif game.state=='bank':
            draw_bank(frame, font, large, m, game.bank_balance, bank_input)
        elif game.state=='saloon':
            draw_saloon(frame, font, large, m)
        else:
            draw_text(frame,large,'YOU WON!' if game.state=='winner' else 'GAME OVER',95,35,(236,185,80))
            draw_text(frame,font,f'Score: ${game.final_score}   Depth: {game.final_depth}ft',47,80)
            draw_text(frame,font,f'Name: {name_input}_  (Enter to continue)',35,113)
        # Two persistent, context-sensitive footer lines, never over mine tiles.
        pygame.draw.rect(frame,(40,35,30),(0,SH-MSG,SW,MSG))
        pygame.draw.line(frame,(141,111,70),(0,SH-MSG),(SW,SH-MSG))
        draw_text(frame,font,legend(game)[:52],4,SH-MSG+4,(230,208,137))
        draw_text(frame,font,game.message[:52],4,SH-12,(232,223,180))
        # Query the current framebuffer each frame: window resizes can replace it.
        surface = pygame.display.get_surface()
        surface.fill((8, 9, 16))
        vx, vy, vw, vh = viewport(surface.get_size(), (SW, SH))
        scaled = pygame.transform.scale(frame, (vw, vh))
        surface.blit(scaled, (vx, vy))
        pygame.display.flip()
        clock.tick(FPS)
    pygame.quit()


if __name__=='__main__': main()