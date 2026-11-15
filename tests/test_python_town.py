"""Town facade, Mercantile and Assay Office display regression tests."""
import os
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'python'))
from miners_claim.engine import Game, PRICES


class TradingRulesTests(unittest.TestCase):
    def setUp(self):
        self.game = Game(seed=7)

    def test_store_boundaries_and_no_remote_purchase(self):
        game = self.game
        game.state = 'mine'
        game.miner.x = 8
        self.assertTrue(game.enter_store())
        cash = game.miner.money
        self.assertTrue(game.buy('shovel'))
        self.assertEqual(game.miner.money, cash-PRICES['shovel'])
        game.state = 'mine'
        self.assertFalse(game.buy('pickaxe'))
        self.assertEqual(game.miner.money, cash-PRICES['shovel'])
        game.miner.x = 40
        self.assertFalse(game.enter_store())

    def test_assay_boundaries_partial_and_full_sale(self):
        game = self.game
        game.state = 'mine'
        game.miner.x = 31
        self.assertTrue(game.enter_assay())
        game.miner.haul = 45
        cash = game.miner.money
        self.assertEqual(game.sell(20), 20)
        self.assertEqual(game.miner.haul, 25)
        self.assertEqual(game.sell(100), 25)
        self.assertEqual(game.miner.money, cash+45)
        game.state = 'mine'
        game.miner.x = 40
        self.assertFalse(game.enter_assay())
        self.assertEqual(game.sell(10), 0)


class TownRenderingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.environ.setdefault('SDL_VIDEODRIVER', 'dummy')
        os.environ.setdefault('SDL_AUDIODRIVER', 'dummy')
        try:
            import pygame
        except ImportError:
            raise unittest.SkipTest('pygame-ce is not installed')
        cls.pygame = pygame
        pygame.init()

    @classmethod
    def tearDownClass(cls):
        cls.pygame.quit()

    def test_facades_follow_camera_and_hide_underground(self):
        from miners_claim.town import visible_facades
        self.assertEqual(len(visible_facades(0,0)), 2)
        self.assertEqual(len(visible_facades(0,4)), 0)
        facades = visible_facades(19,0)
        self.assertEqual([label for label, _ in facades], ['bank', 'assay'])
        self.assertEqual(len(visible_facades(0,0,'legacy')), 2)

    def test_town_and_interior_screens_render(self):
        from miners_claim.town import draw_town, draw_store, draw_assay, draw_bank, draw_saloon
        pygame=self.pygame
        surface = pygame.Surface((320,200))
        font = pygame.font.Font(None, 14)
        large = pygame.font.Font(None, 20)
        game=Game(seed=7)
        for camera_x, camera_y in ((0,0),(10,0),(20,0),(0,1),(20,2)):
            draw_town(surface, camera_x, camera_y, font)
        self.assertEqual(surface.get_clip(), surface.get_rect())
        draw_store(surface, font, large, game.miner, PRICES)
        draw_assay(surface, font, large, game.miner, '12')
        draw_bank(surface, font, large, game.miner, 145, '20')
        draw_saloon(surface, font, large, game.miner)
        self.assertNotEqual(surface.get_at((160,30))[:3],(19,21,27))