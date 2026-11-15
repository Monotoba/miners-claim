"""Regression tests for dangerous water and gas pockets in tunnels."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'python'))
from miners_claim.engine import Game, AIR, GAS, WATER, DIRT1


class ActiveHazardTests(unittest.TestCase):
    def setUp(self):
        self.game = Game(seed=101)
        self.game.state = 'mine'
        self.m = self.game.miner
        self.m.x, self.m.y, self.m.lantern = 40, 10, 1
        # Deliberately isolate one pocket; no map RNG assumptions.
        for y in range(8, 13):
            for x in range(38, 44):
                self.game.world[y][x] = DIRT1
        self.game.world[10][40] = AIR

    def test_water_is_not_a_solid_walkable_platform(self):
        self.game.world[11][40] = WATER
        self.game.tick()
        self.assertEqual(self.m.lives, 4)
        self.assertEqual((self.m.x, self.m.y), (8, 1))
        self.assertEqual(self.game.world[11][40], WATER)

    def test_gas_exposure_warns_then_causes_life_loss(self):
        self.game.world[10][41] = GAS
        self.game.tick()
        self.assertEqual(self.m.lives, 5)
        self.assertEqual(self.game.hazard_kind, 'gas')
        self.assertIn('GAS LEAK', self.game.message)
        for _ in range(19):
            self.game.tick()
        self.assertEqual(self.m.lives, 4)
        self.assertIsNone(self.game.hazard_kind)
        self.assertEqual(self.game.world[10][41], GAS)

    def test_water_exposure_resets_after_escape(self):
        self.game.world[10][41] = WATER
        for _ in range(12):
            self.game.tick()
        self.assertEqual(self.game.hazard_kind, 'water')
        self.assertEqual(self.game.hazard_exposure, 12)
        self.m.x = 38
        self.game.tick()
        self.assertEqual(self.game.hazard_exposure, 0)
        self.assertEqual(self.m.lives, 5)

    def test_direct_water_and_gas_contact_does_not_destroy_pocket(self):
        for tile in (WATER, GAS):
            with self.subTest(tile=tile):
                g = Game(seed=101)
                g.state = 'mine'
                g.miner.x, g.miner.y, g.miner.lantern = 40, 10, 1
                g.world[10][41] = tile
                self.assertFalse(g.try_move(1, 0))
                self.assertEqual(g.miner.lives, 4)
                self.assertEqual(g.world[10][41], tile)

    def test_hazard_transients_reset_when_loading_save(self):
        self.game.world[10][41] = GAS
        self.game.check_hazards()
        loaded = Game.from_dict(self.game.to_dict())
        self.assertIsNone(loaded.hazard_kind)
        self.assertEqual(loaded.hazard_exposure, 0)
        self.assertEqual(loaded.to_dict(), self.game.to_dict())


if __name__ == '__main__':
    unittest.main()