"""Pygame UI for the Miner's Claim Python port."""
from __future__ import annotations
import argparse
from pathlib import Path
import pygame
from .engine import (Game, WIDTH, HEIGHT, TILE, AIR, GRASS, DIRT1, DIRT2, DIRT3,
                     ROCK, GOLD, SILVER, GEM, WATER, GAS, SAND, SNAKE, LADDER, BEDROCK, PRICES)

SW, SH, HUD, MSG, SCALE, FPS = 320, 200, 24, 16, 3, 30
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


def main(argv=None):
    parser=argparse.ArgumentParser(description="Miner's Claim (Python edition)")
    parser.add_argument('--scale',type=int,choices=range(1,7),metavar='1..6',default=3)
    parser.add_argument('--seed',type=int,default=None)
    parser.add_argument('--load-qb64',type=Path,help='Import original QB64 V1/V2 save')
    args=parser.parse_args(argv)
    pygame.init()
    surface=pygame.display.set_mode((SW*args.scale,SH*args.scale))
    pygame.display.set_caption("Miner's Claim — Python Edition")
    frame=pygame.Surface((SW,SH))
    font=pygame.font.Font(None,14)
    large=pygame.font.Font(None,20)
    clock=pygame.time.Clock()
    save_path=Path.home()/'.local'/'share'/'miners-claim'/SAVE_NAME
    game=Game.import_qb64(args.load_qb64) if args.load_qb64 else Game(seed=args.seed)
    sale_input='';name_input='';scores=[];move_delay=0
    camera_x=camera_y=0
    running=True
    while running:
        for event in pygame.event.get():
            if event.type==pygame.QUIT: running=False; continue
            if event.type!=pygame.KEYDOWN: continue
            key=event.key
            if key==pygame.K_ESCAPE:
                if game.state=='assay': game.state='mine'
                elif game.state in ('mine','store'): game._end_run('You abandoned the claim.')
                else: running=False
                continue
            if game.state=='store':
                if pygame.K_1<=key<=pygame.K_8:
                    game.buy(list(PRICES)[key-pygame.K_1])
                elif key==pygame.K_l: game.state='mine'
            elif game.state=='mine':
                if key==pygame.K_j: game.jump()
                elif key==pygame.K_l: game.ladder()
                elif key==pygame.K_t: game.drop_tnt()
                elif key==pygame.K_p: game.pickup()
                elif key==pygame.K_m: game.enter_store()
                elif key==pygame.K_s: game.enter_assay();sale_input=''
            elif game.state=='assay':
                if pygame.K_0<=key<=pygame.K_9 and len(sale_input)<6:
                    sale_input+=chr(key)
                elif key==pygame.K_BACKSPACE: sale_input=sale_input[:-1]
                elif key==pygame.K_RETURN and sale_input:
                    game.sell(int(sale_input));sale_input=''
                elif key==pygame.K_a: game.sell(game.miner.haul);sale_input=''
                elif key==pygame.K_c: sale_input=''
                elif key in (pygame.K_l,pygame.K_m): game.state='mine'
            elif game.state in ('nameentry','winner'):
                if key==pygame.K_RETURN:
                    scores.append((name_input.strip()[:12] or 'MINER',game.final_score or game.miner.money+game.miner.haul,game.final_depth or game.depth_feet))
                    scores.sort(key=lambda row:row[1],reverse=True);scores=scores[:10]
                    game=Game();name_input='';game.state='store'
                elif key==pygame.K_BACKSPACE: name_input=name_input[:-1]
                elif event.unicode.isprintable() and len(name_input)<12: name_input+=event.unicode
            if key==pygame.K_F5 and game.state in ('mine','store','assay'):
                try: game.save(save_path);game.message=f'Saved to {save_path}'
                except OSError as ex: game.message=f'Save failed: {ex}'
            if key==pygame.K_F9:
                try: game=Game.load(save_path);game.message='Saved game loaded.'
                except (OSError,ValueError,KeyError,TypeError) as ex: game.message=f'Load failed: {ex}'

        if move_delay: move_delay-=1
        if game.state=='mine' and move_delay==0:
            keys=pygame.key.get_pressed()
            dx= -1 if keys[pygame.K_LEFT] else 1 if keys[pygame.K_RIGHT] else 0
            dy= -1 if keys[pygame.K_UP] else 1 if keys[pygame.K_DOWN] else 0
            if dx or dy:
                game.try_move(dx,0) if dx else game.try_move(0,dy)
                move_delay=4
        game.tick()
        frame.fill((15,13,23))
        m=game.miner
        if game.state=='mine':
            # Fixed-size logical viewport, draw only visible tiles.
            camera_x=max(0,min(WIDTH-20,m.x-10))
            camera_y=max(0,min(HEIGHT-10,m.y-5))
            for sy in range(10):
                y=sy+camera_y
                for sx in range(20):
                    x=sx+camera_x;t=game.world[y][x]
                    px,py=sx*TILE,HUD+sy*TILE
                    c=COLORS[t]
                    pygame.draw.rect(frame,c,(px,py,TILE,TILE))
                    if t in (DIRT1,DIRT2,DIRT3,ROCK,SAND):
                        pygame.draw.circle(frame,tuple(max(0,v-20) for v in c),(px+((x*7+y*3)%13)+1,py+((x*3+y*11)%13)+1),2)
                    if t==LADDER:
                        pygame.draw.line(frame,(90,53,22),(px+4,py),(px+4,py+15),2)
                        pygame.draw.line(frame,(90,53,22),(px+12,py),(px+12,py+15),2)
                        for j in range(3,15,5):pygame.draw.line(frame,(235,185,90),(px+4,py+j),(px+12,py+j),2)
                    elif t in (GOLD,SILVER,GEM):
                        pygame.draw.circle(frame,(245,244,240),(px+8,py+7),3)
                    elif t==WATER: pygame.draw.line(frame,(100,185,255),(px,py+7),(px+15,py+7),2)
                    elif t==GAS: pygame.draw.circle(frame,(182,220,116),(px+8,py+8),5,1)
                    elif t==SNAKE: pygame.draw.arc(frame,(240,195,105),(px+2,py+2,12,12),0,5,2)
                    if game.loot[y][x]: pygame.draw.circle(frame,(252,232,130),(px+11,py+11),2)
            px=(m.x-camera_x)*TILE;py=HUD+(m.y-camera_y)*TILE
            pygame.draw.rect(frame,(238,210,145),(px+4,py+2,8,11))
            pygame.draw.rect(frame,(65,133,203),(px+5,py+10,6,5))
            pygame.draw.rect(frame,(245,212,49),(px+3,py,10,4))
            if game.tnt_active:
                x=(game.tnt_x-camera_x)*TILE+8;y=HUD+(game.tnt_y-camera_y)*TILE+7
                if 0<=x<SW and HUD<=y<SH-MSG:
                    pygame.draw.circle(frame,(240,65,42),(x,y),5)
            pygame.draw.rect(frame,(42,35,25),(0,0,SW,HUD))
            draw_text(frame,font,f'${m.money}  HAUL ${m.haul}/{game.capacity}  LIFE {m.lives}  DEPTH {game.depth_feet}ft',3,2)
            draw_text(frame,font,f'F{m.food} W{m.water} L{m.ladders} TNT{m.tnt}  Tools:{"S" if m.shovel else "-"}{"P" if m.pickaxe else "-"}{"Lan" if m.lantern else ""}',3,13)
        elif game.state=='store':
            draw_text(frame,large,'MERCANTILE — MINER\'S CLAIM',20,12,(246,205,95))
            for i,(item,price) in enumerate(PRICES.items()):
                draw_text(frame,font,f'{i+1}. {item:<12} ${price:>2}',48,39+i*14)
            draw_text(frame,font,f'Cash: ${m.money}    Press L to leave',35,159)
        elif game.state=='assay':
            draw_text(frame,large,'ASSAY OFFICE',70,18,(238,198,96))
            draw_text(frame,font,f'Haul: ${m.haul}      Cash: ${m.money}',55,58)
            draw_text(frame,font,f'Sell amount: ${sale_input}_',55,85)
            draw_text(frame,font,'Enter=Sell  A=All  C=Clear  L=Exit',17,122)
        else:
            draw_text(frame,large,'YOU WON!' if game.state=='winner' else 'GAME OVER',95,35,(236,185,80))
            draw_text(frame,font,f'Score: ${game.final_score}   Depth: {game.final_depth}ft',47,80)
            draw_text(frame,font,f'Name: {name_input}_  (Enter to continue)',35,113)
        pygame.draw.rect(frame,(40,35,30),(0,SH-MSG,SW,MSG))
        draw_text(frame,font,game.message[:55],4,SH-12,(232,223,180))
        scaled=pygame.transform.scale(frame,surface.get_size())
        surface.blit(scaled,(0,0));pygame.display.flip()
        clock.tick(FPS)
    pygame.quit()


if __name__=='__main__': main()