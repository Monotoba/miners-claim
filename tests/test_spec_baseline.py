"""Static source/spec baseline checks; NOT QB64 execution or gameplay tests."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'original-qb64' / 'MinersClaim_QB64_v29_simple_tnt_timer.bas'
SPEC = ROOT / 'specifications' / 'GAME_DESIGN_V1.md'


class TestSpecificationBaseline(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SOURCE.read_text(encoding='utf-8-sig')
        cls.spec = SPEC.read_text(encoding='utf-8')

    def test_spec_present_and_identifies_exact_source(self):
        self.assertIn(SOURCE.name, self.spec)
        self.assertIn('not proof of correct runtime behavior', self.spec)

    def test_critical_constants_match_baseline(self):
        expected = {
            'SCRW': 320, 'SCRH': 200, 'SCREEN_SCALE': 6,
            'MW': 128, 'MH': 96, 'TILE': 16, 'SURFACE_Y': 2,
            'CLAIM_SHAFT_X': 28, 'WIN_GOAL': 1000000,
            'TNT_COUNTDOWN_FRAMES': 300, 'TNT_RADIUS': 5,
        }
        for name, value in expected.items():
            with self.subTest(name=name):
                match = re.search(r'^CONST\s+' + name + r'\s*=\s*(\d+)\s*$', self.source, re.M)
                self.assertIsNotNone(match)
                self.assertEqual(int(match.group(1)), value)

    def test_known_save_headers_and_filename(self):
        for token in ['MINERS_CLAIM_SAVE_V1', 'MINERS_CLAIM_SAVE_V2',
                      'MINERS_CLAIM_SCORES_V1', 'miners_claim_save.txt',
                      'miners_claim_scores.txt']:
            with self.subTest(token=token):
                self.assertIn(token, self.source)
                self.assertIn(token, self.spec)

    def test_mechanics_exist_in_source(self):
        for name in ['InitGame', 'AddStarterDeposits', 'DigTile', 'ApplyGravity',
                     'ConsumeProvisions', 'ExplodeTNT', 'PickupLooseLoot',
                     'SaveGame', 'LoadGame', 'CheckWin']:
            with self.subTest(name=name):
                self.assertRegex(self.source, r'(?m)^SUB ' + name + r'\b')


if __name__ == '__main__':
    unittest.main()
