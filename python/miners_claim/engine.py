"""Deterministic, pygame-independent rules ported from archived QB64 v29.

Differences: seeded Python random terrain (not QB64 RND); validated JSON save
format with optional QB64 V1/V2 import; explicit terminal state handling.
"""
from __future__ import annotations
from dataclasses import asdict, dataclass
from pathlib import Path
import json
import os
import random
from .townplan import FRONTIER_SHAFT, near

WIDTH, HEIGHT, TILE = 128, 96, 16
SURFACE, SHAFT, WIN_GOAL = 2, FRONTIER_SHAFT, 1_000_000
AIR, GRASS, DIRT1, DIRT2, DIRT3, ROCK, GOLD, SILVER, GEM, WATER, GAS, SAND, SNAKE, LADDER, BEDROCK = range(15)
VALUE = {GOLD: 20, SILVER: 12, GEM: 45}
PRICES = {'shovel': 10, 'pickaxe': 15, 'wheelbarrow': 30, 'ladders': 20,
          'food': 5, 'water': 5, 'lantern': 10, 'tnt': 25}
TOOLS = {'shovel', 'pickaxe', 'wheelbarrow', 'lantern'}
SAVE_VERSION = 1
FIELDS = ('x', 'y', 'lives', 'money', 'food', 'water', 'ladders', 'shovel',
          'pickaxe', 'wheelbarrow', 'lantern', 'tnt', 'haul', 'steps', 'deepest')


@dataclass
class Miner:
    x: int = 8
    y: int = 1
    lives: int = 5
    money: int = 150
    food: int = 0
    water: int = 0
    ladders: int = 0
    shovel: int = 0
    pickaxe: int = 0
    wheelbarrow: int = 0
    lantern: int = 0
    tnt: int = 0
    haul: int = 0
    steps: int = 0
    deepest: int = 0


class Game:
    def __init__(self, seed: int | None = None):
        self.rng = random.Random(seed)
        self.miner = Miner()
        self.world = [[self.base_tile(y) for x in range(WIDTH)] for y in range(HEIGHT)]
        self.loot = [[0] * WIDTH for _ in range(HEIGHT)]
        self.state = 'store'
        self.town_layout = 'frontier'
        self.bank_balance = 0
        self.last_cards = None
        self.encounter_kind = None
        self.encounter_cooldown = 0
        self.message = 'WEST: stores, bank, assay and saloon. EAST: the mine shaft.'
        self.tnt_active = False
        self.tnt_x = self.tnt_y = self.tnt_frames = 0
        self.jump_grace = 0
        self.hazard_kind = None
        self.hazard_exposure = 0
        self.hazard_limit = 0
        self.final_score = 0
        self.final_depth = 0
        self._generate()

    @staticmethod
    def base_tile(y: int) -> int:
        if y < SURFACE: return AIR
        if y == SURFACE: return GRASS
        if y < 18: return DIRT1
        if y < 38: return DIRT2
        if y < 58: return DIRT3
        if y < HEIGHT - 2: return ROCK
        return BEDROCK

    @staticmethod
    def bounds(x: int, y: int) -> bool:
        return 0 <= x < WIDTH and 0 <= y < HEIGHT

    def _generate(self):
        r, w = self.rng.random, self.world
        for x in range(1, WIDTH - 1):
            for y in range(SURFACE + 2, HEIGHT - 2):
                if r() < .020 and y > 4: w[y][x] = GOLD
                if r() < .014 and y > 10: w[y][x] = SILVER
                if r() < .006 and y > 18: w[y][x] = GEM
                if r() < .006 and y > 14: w[y][x] = SNAKE
                if r() < .006 and y > 20: w[y][x] = GAS
                if r() < .004 and y > 12: w[y][x] = WATER
                if r() < .020 and 34 < y < 62: w[y][x] = SAND
        for _ in range(120):
            cx = 2 + int(r() * (WIDTH - 4))
            cy = SURFACE + 4 + int(r() * (HEIGHT - SURFACE - 8))
            radius = 1 + int(r() * 3)
            if cy < 18: kind = GOLD if r() < .55 else DIRT1
            elif cy < 35:
                if r() < .25: kind = WATER
                elif r() < .55: kind = SILVER  # independent QB64 RND draws
                else: kind = DIRT2
            elif cy < 58:
                if r() < .25: kind = GAS
                elif r() < .55: kind = SAND
                elif r() < .72: kind = GEM
                else: kind = DIRT3
            else:
                if r() < .22: kind = GEM
                elif r() < .45: kind = GAS
                else: kind = ROCK
            for y in range(cy - radius, cy + radius + 1):
                for x in range(cx - radius, cx + radius + 1):
                    if self.bounds(x,y) and (x-cx)**2 + (y-cy)**2 <= radius**2 + int(r()*2):
                        if SURFACE < y < HEIGHT - 2: w[y][x] = kind
        for y in range(SURFACE - 1, SURFACE + 8): w[y][SHAFT] = LADDER
        for y in range(SURFACE + 5, SURFACE + 8):
            for x in range(SHAFT - 3, SHAFT + 5): w[y][x] = AIR
        for x in range(SHAFT + 9): w[1][x] = AIR
        for y in range(SURFACE + 1, SURFACE + 11):
            for x in range(SHAFT - 6, SHAFT + 11):
                if w[y][x] in (WATER, GAS, SNAKE, SAND): w[y][x] = DIRT1
        for y in range(SURFACE - 1, SURFACE + 8): w[y][SHAFT] = LADDER
        deposits = [(-1,1,GOLD),(1,1,GOLD),(-2,1,SILVER),(2,1,SILVER),
                    (-1,2,SILVER),(1,2,GEM),(-2,2,GOLD),(2,2,GOLD),
                    (4,5,GOLD),(5,5,GOLD),(4,6,SILVER),(5,6,GEM),(3,7,GEM),
                    (8,6,GOLD),(9,7,SILVER),(10,8,GOLD),(12,9,GEM)]
        for dx,dy,t in deposits: w[SURFACE+dy][SHAFT+dx] = t

    @property
    def capacity(self): return 300 if self.miner.wheelbarrow else 75

    @property
    def depth_feet(self): return max(0, (self.miner.deepest - SURFACE) * 10)

    def buy(self, item: str) -> bool:
        if self.state != 'store' or item not in PRICES: return False
        m = self.miner
        if item in TOOLS and getattr(m,item):
            self.message = f'Already own {item}.'; return False
        if m.money < PRICES[item]:
            self.message = 'You do not have enough money.'; return False
        m.money -= PRICES[item]
        setattr(m,item,getattr(m,item)+1)
        self.message = f'Bought {item}.'
        return True

    def near_store(self):
        return near(self.town_layout, 'mercantile', self.miner.x, self.miner.y)

    def near_assay(self):
        return near(self.town_layout, 'assay', self.miner.x, self.miner.y)

    def near_bank(self):
        return near(self.town_layout, 'bank', self.miner.x, self.miner.y)

    def near_saloon(self):
        return near(self.town_layout, 'saloon', self.miner.x, self.miner.y)

    def enter_bank(self):
        if self.state == 'mine' and self.near_bank():
            self.state = 'bank'
            self.message = 'Bank: enter amount, D deposit or W withdraw.'
            return True
        self.message = 'Stand near the BANK and press B.'
        return False

    def deposit(self, amount: int) -> int:
        if self.state != 'bank' or amount <= 0:
            self.message = 'Enter a positive amount to deposit.'
            return 0
        if amount > self.miner.money:
            self.message = 'Not enough cash to deposit.'
            return 0
        self.miner.money -= amount
        self.bank_balance += amount
        self.message = f'Deposited ${amount}. Bank balance ${self.bank_balance}.'
        self._check_win()
        return amount

    def withdraw(self, amount: int) -> int:
        if self.state != 'bank' or amount <= 0:
            self.message = 'Enter a positive amount to withdraw.'
            return 0
        if amount > self.bank_balance:
            self.message = 'Insufficient bank funds.'
            return 0
        self.bank_balance -= amount
        self.miner.money += amount
        self.message = f'Withdrew ${amount}. Bank balance ${self.bank_balance}.'
        self._check_win()
        return amount

    def enter_saloon(self):
        if self.state == 'mine' and self.near_saloon():
            self.state = 'saloon'
            self.message = 'Saloon: D drink ($5); P play high-card ($10).'
            return True
        self.message = 'Stand near the SALOON and press N.'
        return False

    def buy_drink(self) -> bool:
        # A drink is one water provision; it does not alter mining tools.
        if self.state != 'saloon':
            return False
        if self.miner.money < 5:
            self.message = 'Not enough cash for a drink ($5).'
            return False
        self.miner.money -= 5
        self.miner.water += 1
        self.message = 'Bought a drink for $5. Water +1.'
        return True

    def play_cards(self, bet: int = 10) -> int:
        """Single round of high card; positive means winnings, negative loss.

        Draws one rank per player from 1..13, compares them, pays even
        money on a win, refunds on a tie. No real-money functionality.
        """
        if self.state != 'saloon' or bet <= 0:
            return 0
        if self.miner.money < bet:
            self.message = f'Need ${bet} cash to play.'
            return 0
        player = self.rng.randint(1, 13)
        dealer = self.rng.randint(1, 13)
        result = (player > dealer) - (player < dealer)
        delta = bet * result
        self.miner.money += delta
        self.last_cards = (player, dealer, delta)
        self._check_win()
        word = 'WON' if delta > 0 else 'LOST' if delta < 0 else 'TIE'
        self.message = f'Cards: you {player}, dealer {dealer}. {word} ${abs(delta)}.'
        return delta

    def enter_store(self):
        if self.state == 'mine' and self.near_store():
            self.state='store'; self.message='Welcome to the Mercantile.'; return True
        self.message='Stand near the Mercantile and press M.'; return False

    def enter_assay(self):
        if self.state == 'mine' and self.near_assay():
            self.state='assay'; self.message='Assayer: enter amount or press A to sell all.'; return True
        self.message='Stand near ASSAY and press S.'; return False

    def sell(self, amount: int) -> int:
        if self.state != 'assay': return 0
        if self.miner.haul <= 0 or amount <= 0:
            self.message='No positive haul to sell.'; return 0
        sold = min(amount,self.miner.haul)
        self.miner.haul -= sold
        self.miner.money += sold
        self.message=f'Assayer paid ${sold}.'
        self._check_win()
        return sold

    def _end_run(self, why: str):
        self.final_score=self.miner.money+self.bank_balance+self.miner.haul
        self.final_depth=self.depth_feet
        self.state='nameentry'
        self.message=why

    def lose_life(self, why: str):
        m=self.miner
        m.lives -= 1; m.haul=0
        self.encounter_kind = None
        self.encounter_cooldown = 0
        self.hazard_kind = None
        self.hazard_exposure = self.hazard_limit = 0
        if m.lives <= 0: self._end_run(why+' No lives remain.')
        else:
            m.x=8; m.y=1
            self.message=why+' You lost a life and dropped your haul.'

    def _check_gameover(self):
        m=self.miner
        if self.state == 'mine' and m.money <= 0 and self.bank_balance <= 0 and m.haul <= 0 and m.food <= 0 and m.water <= 0 and not m.shovel and not m.pickaxe:
            self._end_run('The claim is lost.')

    def _check_win(self):
        if self.state in ('mine','assay','bank','saloon') and self.miner.money + self.bank_balance >= WIN_GOAL:
            self.final_score=self.miner.money+self.bank_balance+self.miner.haul
            self.final_depth=self.depth_feet
            self.state='winner'; self.message='You won the claim!'

    def _move(self,x,y):
        m=self.miner
        previous_x = m.x
        m.x=x; m.y=y; m.steps += 1; m.deepest=max(m.deepest,y)
        if y > SURFACE:
            if m.steps % 60 == 0:
                if m.water: m.water-=1
                else: self.lose_life('You ran out of water underground.'); return
            if m.steps % 100 == 0:
                if m.food: m.food-=1
                else: self.lose_life('You ran out of food underground.')
        if self.state == 'mine' and y <= SURFACE and x != previous_x:
            self._check_street_encounter()

    def _check_street_encounter(self):
        """Random encounters only on horizontal surface walking steps.

        The bandit's per-step chance grows toward the eastern mine.
        No encounter is possible underground, inside buildings, or
        during the post-encounter cooldown. Older maps stay unchanged.
        """
        if self.state != 'mine' or self.town_layout != 'frontier':
            return False
        m = self.miner
        if m.y > SURFACE or not 0 <= m.x <= SHAFT:
            return False
        if self.encounter_cooldown > 0:
            self.encounter_cooldown -= 1
            return False

        # Rare encounter: 0.005% per eligible step at the far west,
        # increasing quadratically to 0.05% at the eastern mine.
        # Chance is checked only while carrying ore or >$300 cash.
        fraction = m.x / SHAFT
        bandit_chance = 0.00005 + 0.00045 * fraction * fraction
        if (m.haul > 0 or m.money > 300) and self.rng.random() < bandit_chance:
            targets = (['ore'] if m.haul > 0 else []) + (
                ['cash'] if m.money > 300 else [])
            stolen = targets[0] if len(targets) == 1 else (
                targets[0] if self.rng.random() < 0.5 else targets[1])
            amount = m.haul if stolen == 'ore' else m.money
            if stolen == 'ore':
                m.haul = 0
            else:
                m.money = 0
            self.state = 'encounter'
            self.encounter_kind = 'bandit'
            self.encounter_cooldown = 24
            self.message = f'BANDIT! Stole all your {stolen}: ${amount}!'
            return True

        if m.money >= 300 and self.rng.random() < 0.012:
            self.state = 'encounter'
            self.encounter_kind = 'banker'
            self.encounter_cooldown = 24
            self.message = 'BANKER: Carrying ${300}+? Deposit cash at the BANK!'
            return True
        return False

    def dismiss_encounter(self) -> bool:
        if self.state != 'encounter':
            return False
        self.encounter_kind = None
        self.state = 'mine'
        return True

    def try_move(self,dx:int,dy:int) -> bool:
        if self.state != 'mine': return False
        m=self.miner; x,y=m.x+dx,m.y+dy
        if not self.bounds(x,y): return False
        if y > SURFACE+2 and not m.lantern:
            self.message='Too dark below two levels. Buy a lantern.'; return False
        t=self.world[y][x]
        if t in (AIR,LADDER):
            if dy == -1 and m.y > SURFACE and self.world[m.y][m.x] != LADDER and t != LADDER:
                self.message='You need a ladder to climb up.'; return False
            self._move(x,y); self._check_gameover(); return True
        if t in (GRASS,DIRT1,DIRT2,DIRT3,SAND):
            if not m.shovel: self.message='You need a shovel.'; return False
            if t == SAND and self.rng.random() < .25:
                self.lose_life('Buried by loose sand.'); self._check_gameover(); return False
        elif t in (ROCK,GOLD,SILVER,GEM):
            if not m.pickaxe: self.message='You need a pickaxe.'; return False
            if t in VALUE and m.haul + VALUE[t] > self.capacity:
                self.message='Haul full. Return to ASSAY.'; return False
        elif t in (WATER,GAS,SNAKE):
            # Water and gas pockets remain dangerous after contact. Snakes
            # are removed after an encounter as in the original prototype.
            if t == SNAKE:
                self.world[y][x] = AIR
            self.lose_life({WATER:'You drowned.',GAS:'Gas pocket exploded.',SNAKE:'A rattlesnake den.'}[t]); return False
        elif t == BEDROCK:
            self.message='Bedrock. Cannot dig.'; return False
        else: return False
        if t in VALUE:
            m.haul+=VALUE[t]; self.message=f'HAUL +${VALUE[t]}.'
        self.world[y][x]=AIR
        self._move(x,y); self._check_gameover(); return True

    def supported(self):
        m=self.miner
        if m.y in (SURFACE-1,SURFACE) or m.y>=HEIGHT-1: return True
        if self.world[m.y][m.x]==LADDER: return True
        return self.world[m.y+1][m.x] not in (AIR, WATER, GAS)

    def jump(self):
        m=self.miner
        if self.state!='mine' or m.y<=0 or not self.supported(): return False
        if self.world[m.y-1][m.x] not in (AIR,LADDER): return False
        self._move(m.x,m.y-1); self.jump_grace=18; return True

    def ladder(self):
        m=self.miner
        if self.state!='mine' or self.world[m.y][m.x] != AIR or m.ladders<=0: return False
        self.world[m.y][m.x]=LADDER; m.ladders-=1
        self.message='Placed ladder.'; return True

    def gravity(self):
        if self.state != 'mine': return
        if self.jump_grace:
            self.jump_grace-=1; return
        m=self.miner
        if self.supported() or m.y+1>=HEIGHT: return
        if m.y+1 > SURFACE+2 and not m.lantern: return
        below = self.world[m.y+1][m.x]
        if below in (WATER, GAS):
            self.lose_life('Fell into water.' if below == WATER else 'Fell into a gas pocket.')
            return
        if below in (AIR,LADDER):
            m.y+=1; m.steps+=1; m.deepest=max(m.deepest,m.y)
            self.message='You fall!'

    def check_hazards(self):
        """Expose a miner in an open tunnel to adjacent water or toxic gas.

        Pockets have an active danger zone rather than acting as harmless
        support blocks. Exposure has a short warning window for escape.
        The counter is transient, not written into legacy-compatible saves.
        """
        m = self.miner
        if self.state != 'mine' or m.y <= SURFACE:
            self.hazard_kind = None
            self.hazard_exposure = self.hazard_limit = 0
            return
        tile = self.world[m.y][m.x]
        if tile in (WATER, GAS):
            self.lose_life('Drowned in water.' if tile == WATER else 'Overcome by gas.')
            return
        neighbors = [
            self.world[ny][nx]
            for nx, ny in ((m.x-1,m.y), (m.x+1,m.y), (m.x,m.y-1), (m.x,m.y+1))
            if self.bounds(nx,ny)
        ]
        kind = 'gas' if GAS in neighbors else 'water' if WATER in neighbors else None
        if kind is None:
            self.hazard_kind = None
            self.hazard_exposure = self.hazard_limit = 0
            return
        if kind != self.hazard_kind:
            self.hazard_kind = kind
            self.hazard_exposure = 0
            self.hazard_limit = 20 if kind == 'gas' else 35
        self.hazard_exposure += 1
        if self.hazard_exposure >= self.hazard_limit:
            self.lose_life('Overcome by leaking gas.' if kind == 'gas'
                           else 'Flooded by a water pocket.')
        elif self.hazard_exposure == 1:
            self.message = ('GAS LEAK! Move away!' if kind == 'gas'
                            else 'WATER SEEPAGE! Move away!')

    def drop_tnt(self):
        m=self.miner
        if self.state!='mine' or m.tnt<=0 or self.tnt_active or m.y<=SURFACE:
            self.message='Cannot drop TNT here.'; return False
        m.tnt-=1; self.tnt_active=True
        self.tnt_x,self.tnt_y=m.x,m.y; self.tnt_frames=300
        self.message='TNT dropped! Ten seconds! Run!'; return True

    def tick(self):
        if self.state in ('store','mine','assay','bank','saloon') and self.tnt_active:
            self.tnt_frames-=1
            if self.tnt_frames<=0: self.explode()
        if self.state == 'mine':
            self.gravity()
            self.check_hazards()
            self._check_gameover()
            self._check_win()

    def explode(self):
        if not self.tnt_active: return
        cx,cy=self.tnt_x,self.tnt_y
        self.tnt_active=False; self.tnt_frames=0
        m=self.miner
        if (m.x-cx)**2+(m.y-cy)**2 <=25:
            self.lose_life('Caught in a TNT blast.'); return
        destroyed=blasted=0
        for y in range(max(SURFACE+1,cy-5),min(HEIGHT,cy+6)):
            for x in range(max(0,cx-5),min(WIDTH,cx+6)):
                if (x-cx)**2+(y-cy)**2>25 or self.world[y][x]==BEDROCK: continue
                t=self.world[y][x]
                value=VALUE.get(t,0)
                self.loot[y][x]+=value; blasted+=value
                if t!=AIR: destroyed+=1
                self.world[y][x]=AIR
        self.message=f'BOOM! Cleared {destroyed} tiles; ${blasted} loose ore.'

    def pickup(self):
        if self.state!='mine': return 0
        m=self.miner; got=0
        for y in range(max(0,m.y-1), min(HEIGHT,m.y+2)):
            for x in range(max(0,m.x-1), min(WIDTH,m.x+2)):
                value=self.loot[y][x]
                if value>0:
                    room=self.capacity-m.haul
                    if room<=0:
                        self.message='Your haul is full.'; return got
                    delta=min(value,room)
                    m.haul+=delta; self.loot[y][x]-=delta; got+=delta
        self.message=f'Picked up ${got} loose ore.' if got else 'No loose ore nearby.'
        return got

    def to_dict(self):
        return {'format':'miners-claim-python-v1', 'miner':asdict(self.miner),
                'world':self.world,'loot':self.loot,'state':self.state,
                'tnt':[self.tnt_active,self.tnt_x,self.tnt_y,self.tnt_frames],
                'jump_grace':self.jump_grace,
                'town_layout':self.town_layout,
                'bank_balance':self.bank_balance}

    @classmethod
    def from_dict(cls,data):
        if data.get('format')!='miners-claim-python-v1': raise ValueError('Incompatible save')
        obj=cls.__new__(cls); obj.rng=random.Random()
        if set(data['miner'])!=set(FIELDS): raise ValueError('Invalid miner fields')
        obj.miner=Miner(**{k:int(v) for k,v in data['miner'].items()})
        obj.world=data['world']; obj.loot=data['loot']
        if any(len(a)!=HEIGHT or any(len(row)!=WIDTH for row in a) for a in (obj.world,obj.loot)):
            raise ValueError('Wrong world dimensions')
        if any(not isinstance(t,int) or not 0<=t<=BEDROCK for row in obj.world for t in row):
            raise ValueError('Invalid tile')
        if any(not isinstance(t,int) or t<0 for row in obj.loot for t in row):
            raise ValueError('Invalid loot')
        if not cls.bounds(obj.miner.x,obj.miner.y) or obj.miner.lives<1:
            raise ValueError('Invalid player')
        obj.tnt_active,obj.tnt_x,obj.tnt_y,obj.tnt_frames=data['tnt']
        if obj.tnt_active and (not cls.bounds(obj.tnt_x,obj.tnt_y) or not 0<=obj.tnt_frames<=300):
            raise ValueError('Invalid TNT')
        obj.town_layout = data.get('town_layout', 'legacy')
        if obj.town_layout not in ('legacy', 'frontier'):
            raise ValueError('Invalid town layout')
        obj.bank_balance = data.get('bank_balance', 0)
        if type(obj.bank_balance) is not int or obj.bank_balance < 0:
            raise ValueError('Invalid bank balance')
        obj.state=data['state']
        permitted = ('mine','store','assay','bank','saloon') if obj.town_layout == 'frontier' else ('mine','store','assay')
        if obj.state not in permitted: raise ValueError('Invalid state')
        obj.jump_grace=int(data['jump_grace'])
        obj.message='Saved game loaded.';obj.final_score=obj.final_depth=0
        obj.last_cards = None
        obj.encounter_kind = None
        obj.encounter_cooldown = 0
        obj.hazard_kind=None;obj.hazard_exposure=obj.hazard_limit=0
        return obj

    def save(self,path:Path):
        path=Path(path); path.parent.mkdir(parents=True,exist_ok=True)
        tmp=path.with_suffix(path.suffix+'.tmp')
        try:
            with tmp.open('w',encoding='utf-8') as f:
                json.dump(self.to_dict(),f,separators=(',',':'))
                f.flush();os.fsync(f.fileno())
            os.replace(tmp,path)
        finally:
            tmp.unlink(missing_ok=True)

    @classmethod
    def load(cls,path:Path):
        path=Path(path)
        if path.stat().st_size>2_000_000: raise ValueError('Oversized save')
        with path.open(encoding='utf-8') as f: data=json.load(f)
        return cls.from_dict(data)

    @classmethod
    def import_qb64(cls,path:Path):
        """Read archived QB64 V1/V2 text saves (not a QB64 writer)."""
        path=Path(path)
        if path.stat().st_size>2_000_000: raise ValueError('Oversized QB64 save')
        parts=path.read_text(encoding='utf-8-sig').splitlines()
        if not parts or parts[0] not in ('MINERS_CLAIM_SAVE_V1','MINERS_CLAIM_SAVE_V2'):
            raise ValueError('Unknown QB64 save format')
        v2=parts[0].endswith('V2'); expected=1+15+(4 if v2 else 0)+WIDTH*HEIGHT*(2 if v2 else 1)
        if len(parts)!=expected: raise ValueError('Truncated/extra QB64 save data')
        nums=[int(v.strip()) for v in parts[1:]]
        obj=cls.__new__(cls); obj.rng=random.Random()
        obj.miner=Miner(**dict(zip(FIELDS,nums[:15])))
        offset=15
        if v2:
            active,x,y,frames=nums[offset:offset+4];offset+=4
            obj.tnt_active=bool(active);obj.tnt_x=x;obj.tnt_y=y
            obj.tnt_frames=max(0,min(300,frames)) if active else 0
        else:
            obj.tnt_active=False;obj.tnt_x=obj.tnt_y=obj.tnt_frames=0
        flat=nums[offset:offset+WIDTH*HEIGHT];offset+=WIDTH*HEIGHT
        obj.world=[flat[i:i+WIDTH] for i in range(0,len(flat),WIDTH)]
        flat=nums[offset:offset+WIDTH*HEIGHT] if v2 else [0]*(WIDTH*HEIGHT)
        obj.loot=[flat[i:i+WIDTH] for i in range(0,len(flat),WIDTH)]
        obj.state='mine';obj.jump_grace=0
        obj.town_layout='legacy';obj.bank_balance=0
        obj.message='Imported QB64 save.';obj.final_score=obj.final_depth=0
        obj.last_cards = None
        obj.encounter_kind = None
        obj.encounter_cooldown = 0
        obj.hazard_kind=None;obj.hazard_exposure=obj.hazard_limit=0
        return cls.from_dict(obj.to_dict())