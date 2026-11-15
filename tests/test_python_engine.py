"""Headless behavioral regression tests for the initial Python port."""
import copy
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'python'))
from miners_claim.engine import (Game, AIR, BEDROCK, GOLD, SILVER, GEM, LADDER,
                                 SNAKE, DIRT1, WIDTH, HEIGHT, SHAFT, SURFACE)


class PythonEngineTests(unittest.TestCase):
    def setUp(self):
        self.g=Game(seed=101)
        self.m=self.g.miner

    def test_initial_state_and_tutorial_deposits(self):
        self.assertEqual((self.m.x,self.m.y,self.m.lives,self.m.money),(8,1,5,150))
        self.assertEqual(self.g.capacity,75)
        self.assertEqual(self.g.world[3][SHAFT],LADDER)
        self.assertEqual(self.g.world[3][SHAFT-1],GOLD)
        self.assertEqual(self.g.world[4][SHAFT+1],GEM)
        self.assertEqual(self.g.world[-1][0],BEDROCK)
        self.assertTrue(all(t not in (9,10,11,12) for row in self.g.world[3:13] for t in row[SHAFT-6:SHAFT+11]))

    def test_buying_and_capacity(self):
        self.assertTrue(self.g.buy('pickaxe'))
        self.assertFalse(self.g.buy('pickaxe'))
        self.assertTrue(self.g.buy('wheelbarrow'))
        self.assertEqual((self.m.money,self.g.capacity),(105,300))
        self.assertTrue(self.g.buy('food'))
        self.assertEqual(self.m.food,1)

    def test_mining_and_capacity_block(self):
        self.g.buy('pickaxe');self.g.state='mine'
        self.m.x=SHAFT;self.m.y=3
        self.assertTrue(self.g.try_move(1,0))
        self.assertEqual(self.m.haul,20)
        self.m.haul=70;self.g.world[3][SHAFT+2]=GOLD
        self.assertFalse(self.g.try_move(1,0))
        self.assertEqual(self.g.world[3][SHAFT+2],GOLD)
        self.assertEqual(self.m.haul,70)

    def test_lantern_and_climb(self):
        self.g.state='mine';self.m.x=SHAFT;self.m.y=4
        self.assertFalse(self.g.try_move(0,1))
        self.g.miner.lantern=1
        self.assertTrue(self.g.try_move(0,1))
        self.assertTrue(self.g.try_move(0,-1))

    def test_hazard_death_and_respawn(self):
        self.g.state='mine';self.g.world[1][9]=SNAKE
        self.m.haul=20
        self.assertFalse(self.g.try_move(1,0))
        self.assertEqual((self.m.lives,self.m.haul,self.m.x,self.m.y),(4,0,8,1))
        self.assertEqual(self.g.world[1][9],AIR)

    def test_step_provisions_intersection(self):
        self.g.state='mine';self.m.x=SHAFT;self.m.y=3
        self.m.steps=59
        self.g._move(SHAFT,3)
        self.assertEqual(self.m.lives,4)
        self.m.x=SHAFT;self.m.y=3;self.m.steps=299
        self.m.water=1;self.m.food=0
        self.g._move(SHAFT,3)
        self.assertEqual((self.m.water,self.m.lives),(0,3))

    def test_gravity_does_not_consume_provisions(self):
        self.g.state='mine';self.m.x=42;self.m.y=10;self.m.lantern=1
        self.g.world[11][42]=AIR;self.g.world[10][42]=AIR
        self.m.steps=59
        self.g.gravity()
        self.assertEqual((self.m.y,self.m.steps,self.m.lives),(11,60,5))

    def test_tnt_death_short_circuits_excavation(self):
        self.g.state='mine';self.m.x=SHAFT;self.m.y=5;self.m.tnt=1
        self.assertTrue(self.g.drop_tnt())
        before=copy.deepcopy(self.g.world)
        self.g.tnt_frames=1;self.g.tick()
        self.assertEqual(self.g.world,before)
        self.assertEqual(self.m.lives,4)
        self.assertFalse(self.g.tnt_active)

    def test_tnt_blast_loot_and_pickup(self):
        self.g.state='mine';self.m.x=SHAFT;self.m.y=5;self.m.tnt=1
        self.g.world[6][SHAFT+1]=GOLD
        self.g.drop_tnt();self.m.x=SHAFT+9;self.m.y=5
        self.g.tnt_frames=1;self.g.tick()
        self.assertEqual(self.g.world[6][SHAFT+1],AIR)
        self.assertEqual(self.g.loot[6][SHAFT+1],20)
        self.m.x=SHAFT+1;self.m.y=6
        self.assertEqual(self.g.pickup(),20)
        self.assertEqual(self.m.haul,20)

    def test_assay_and_victory_predicate(self):
        self.g.state='assay';self.m.haul=45
        self.assertEqual(self.g.sell(20),20)
        self.assertEqual(self.m.haul,25)
        self.assertEqual(self.g.sell(100),25)
        self.m.money=999_999;self.m.haul=2
        self.g._check_win();self.assertNotEqual(self.g.state,'winner')
        self.g.sell(2);self.assertEqual(self.g.state,'winner')

    def test_json_round_trip_and_rejected_corruption(self):
        self.g.state='mine';self.g.world[5][30]=AIR
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'save.json'
            self.g.save(path)
            loaded=Game.load(path)
            self.assertEqual(loaded.to_dict(),self.g.to_dict())
            data=self.g.to_dict();data['world'][0][0]=300
            with self.assertRaises(ValueError):Game.from_dict(data)

    def test_qb64_v1_v2_import(self):
        with tempfile.TemporaryDirectory() as tmp:
            for version in ('V1','V2'):
                path=Path(tmp)/f'{version}.txt'
                fields=[getattr(self.m,k) for k in ('x','y','lives','money','food','water','ladders','shovel','pickaxe','wheelbarrow','lantern','tnt','haul','steps','deepest')]
                parts=[f'MINERS_CLAIM_SAVE_{version}']+list(map(str,fields))
                if version=='V2':parts+=['-1','28','5','200']
                parts += [str(v) for row in self.g.world for v in row]
                if version=='V2':parts += [str(v) for row in self.g.loot for v in row]
                path.write_text('\n'.join(parts)+'\n')
                imported=Game.import_qb64(path)
                self.assertEqual(imported.miner.money,self.m.money)
                self.assertEqual(len(imported.world),HEIGHT)
                self.assertEqual(imported.tnt_active,version=='V2')


if __name__=='__main__': unittest.main()