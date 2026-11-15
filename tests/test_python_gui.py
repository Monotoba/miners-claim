"""Headless Pygame startup smoke test (skips without pygame-ce installed)."""
import os
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'python'))


class PygameSmokeTests(unittest.TestCase):
    def test_desktop_starts_and_exits_cleanly(self):
        try:
            import pygame
        except ImportError:
            self.skipTest('pygame-ce not installed in this environment')
        os.environ.setdefault('SDL_VIDEODRIVER', 'dummy')
        os.environ.setdefault('SDL_AUDIODRIVER', 'dummy')
        from miners_claim.app import main
        with patch.object(pygame.event, 'get', return_value=[pygame.event.Event(pygame.QUIT)]):
            main(['--seed', '23', '--scale', '1'])
        self.assertFalse(pygame.get_init())


    def test_all_terrain_tiles_and_miner_render(self):
        try:
            import pygame
        except ImportError:
            self.skipTest('pygame-ce not installed in this environment')
        os.environ.setdefault('SDL_VIDEODRIVER', 'dummy')
        os.environ.setdefault('SDL_AUDIODRIVER', 'dummy')
        from miners_claim.app import draw_terrain, draw_miner, TILE, COLORS
        pygame.init()
        try:
            canvas = pygame.Surface((TILE * 4, TILE * 4))
            for tile in COLORS:
                with self.subTest(tile=tile):
                    draw_terrain(canvas, tile, 0, 0, 13, 19)
            draw_miner(canvas, TILE, TILE)
        finally:
            pygame.quit()


if __name__ == '__main__':
    unittest.main()