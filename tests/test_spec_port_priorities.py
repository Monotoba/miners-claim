"""Check CoCo feature-retention ranking and its explicit porting scope."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
FILE = ROOT / 'specifications' / 'FEATURE_PRIORITY_COCO.md'
BASELINE = ROOT / 'specifications' / 'GAME_DESIGN_V1.md'


class CoCoFeaturePriorityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = FILE.read_text(encoding='utf-8')

    def test_every_priority_rank_is_present_exactly_once(self):
        ranks = [int(n) for n in re.findall(r'^\\|\\s*(\\d+)\\s*\\|\\s*\\*\\*P[0-4]\\*\\*', self.text, flags=re.M)]
        self.assertEqual(ranks, list(range(1, 41)))

    def test_core_not_removed_in_reduction_sequence(self):
        self.assertIn('**P0 / mandatory:**', self.text)
        self.assertIn('never P0', self.text)
        for name in ('Walk/dig/excavate', 'Ore value and collection', 'Haul limit, return and sale',
                     'Lives, death, restart, end/win', 'Mine/store/assay state transitions'):
            self.assertIn(name, self.text)

    def test_platform_profiles_and_dependencies_present(self):
        for section in ('CoCo 1 minimal target', 'CoCo 2 enhanced target', 'CoCo 3 target',
                        'Bandit-bank protection', 'bank-aware', 'TNT', 'wheelbarrow'):
            self.assertIn(section.lower(), self.text.lower())
        self.assertIn('GAME_DESIGN_V1.md', self.text)
        self.assertIn('FEATURE_PRIORITY_COCO.md', BASELINE.read_text(encoding='utf-8'))

    def test_no_unverified_coco_claims(self):
        self.assertIn('not an assertion that CoCo code or hardware has been tested', self.text)
        self.assertIn('These are **planning estimates**', self.text)


if __name__ == '__main__':
    unittest.main()
