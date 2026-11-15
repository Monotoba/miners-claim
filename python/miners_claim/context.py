"""Context-sensitive mining legend and return-trip wheelbarrow rules.

Pure functions, deliberately separated from Pygame for regression testing.
"""
from __future__ import annotations
from .engine import GOLD, SILVER, GEM, WATER, GAS, SAND, SNAKE, LADDER

ITEM_LABELS = {
    GOLD: 'GOLD $20', SILVER: 'SILVER $12', GEM: 'GEMS $45',
    WATER: 'WATER: DROWN', GAS: 'GAS: TOXIC',
    SAND: 'SAND: CAVE-IN', SNAKE: 'SNAKE: BITE',
    LADDER: 'LADDER: CLIMB',
}


def returning_with_wheelbarrow(miner, facing: int) -> bool:
    """Show a loaded cart on the surface when heading toward the assay zone.

    The Assay Office interaction region is 10..25. From the main shaft at
    x=28, walking left is the normal return route.
    """
    if not (miner.wheelbarrow and miner.haul > 0 and miner.y <= 2):
        return False
    if miner.x > 25:
        return facing < 0
    if miner.x < 10:
        return facing > 0
    return facing != 0


def legend(game) -> str:
    """Return one concise line suitable for the fixed 320px game footer."""
    if game.state == 'store':
        return '1-8 BUY  OWNED=HAVE  L=LEAVE  F5=SAVE'
    if game.state == 'assay':
        return 'ENTER=SELL  A=ALL  C=CLEAR  L=LEAVE'
    if game.state != 'mine':
        return 'ENTER=CONTINUE  F9=LOAD'
    m = game.miner
    if game.hazard_kind:
        remaining = max(0, game.hazard_limit - game.hazard_exposure)
        return f'{game.hazard_kind.upper()} LEAK! MOVE AWAY ({remaining} TICKS)'
    if m.y <= 2:
        return 'M=MERCANTILE S=ASSAY  |  F5=SAVE F9=LOAD'
    near = set()
    for ny in range(max(0, m.y-1), min(len(game.world), m.y+2)):
        row = game.world[ny]
        for nx in range(max(0, m.x-1), min(len(row), m.x+2)):
            if nx == m.x and ny == m.y:
                continue
            near.add(row[nx])
    # Show the greatest nearby danger first, then the nearest valuable ore.
    for t in (GAS, WATER, SNAKE, SAND, GEM, GOLD, SILVER, LADDER):
        if t in near:
            return f'NEAR: {ITEM_LABELS[t]}  |  J=JUMP L=LADDER'
    return 'ORE: GOLD $20 SILVER $12 GEM $45  |  P=PICKUP'

class WheelbarrowCargo:
    """Transient visual load for the round trip between town and the mine.

    Purchases stay in the player's inventory; only their *visual* packages
    are represented in the cart. Mining tools are not magically hauled
    out of the mine. Sales unload the barrow even for a partial sale, with
    unsold haul still held by the gameplay engine for subsequent selling.
    """

    def __init__(self):
        self.cargo = 'empty'
        self.purchases = 0
        self.was_underground = False

    def purchased(self, successful: bool) -> None:
        if successful:
            self.purchases += 1

    def left_mercantile(self, miner) -> None:
        self.cargo = ('supplies' if miner.wheelbarrow and self.purchases
                      else 'empty')
        self.purchases = 0
        self.was_underground = False

    def entered_assay(self) -> None:
        # Depositing the ore is separate from selling it; a partial sale
        # does not put the remaining material back into the wheelbarrow.
        self.cargo = 'empty'
        self.was_underground = False

    def update(self, miner) -> None:
        if not miner.wheelbarrow:
            self.cargo = 'empty'
            self.was_underground = False
        elif miner.y > 2:
            # Supplies stay in the mine, and newly dug ore is loaded on
            # the way out rather than sharing the cart with tools.
            self.cargo = 'empty'
            self.was_underground = True
        elif self.was_underground:
            self.cargo = 'ore' if miner.haul > 0 else 'empty'
            self.was_underground = False
        elif self.cargo == 'ore' and miner.haul <= 0:
            self.cargo = 'empty'

    def should_draw(self, miner) -> bool:
        return bool(miner.wheelbarrow and miner.y <= 2)
