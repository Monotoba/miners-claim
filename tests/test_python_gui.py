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


if __name__ == '__main__':
    unittest.main()