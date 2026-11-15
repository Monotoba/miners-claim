"""Deterministic regression tests for frontier banker and bandit encounters."""
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'python'))
from miners_claim.engine import Game, SHAFT


class StreetEncounterTests(unittest.TestCase):
    def setUp(self):
        self.game = Game(seed=404)
        self.game.state = 'mine'
        self.game.miner.x = 30
        self.game.miner.y = 1

    def test_bank_adviser_requires_at_least_300_cash(self):
        self.game.miner.money = 299
        with patch.object(self.game.rng, 'random', return_value=0):
            self.assertFalse(self.game._check_street_encounter())
        self.game.miner.money = 300
        with patch.object(self.game.rng, 'random', side_effect=[.99, 0]):
            self.assertTrue(self.game._check_street_encounter())
        self.assertEqual(self.game.encounter_kind, 'banker')
        self.assertEqual(self.game.miner.money, 300)
        self.assertEqual(self.game.state, 'encounter')
        self.assertIn('BANK', self.game.message)

    def test_bank_adviser_does_not_run_for_bank_funds_alone(self):
        self.game.miner.money = 0
        self.game.bank_balance = 500
        with patch.object(self.game.rng, 'random', return_value=0):
            self.assertFalse(self.game._check_street_encounter())

    def test_bandit_robs_all_ore_when_cash_is_not_eligible(self):
        m = self.game.miner
        m.haul, m.money = 55, 200
        self.game.bank_balance = 700
        with patch.object(self.game.rng, 'random', return_value=0):
            self.assertTrue(self.game._check_street_encounter())
        self.assertEqual(self.game.encounter_kind, 'bandit')
        self.assertEqual((m.haul, m.money, self.game.bank_balance), (0, 200, 700))
        self.assertIn('$55', self.game.message)

    def test_bandit_robs_cash_above_300_but_not_bank_balance(self):
        m = self.game.miner
        m.haul, m.money = 0, 301
        self.game.bank_balance = 400
        with patch.object(self.game.rng, 'random', return_value=0):
            self.assertTrue(self.game._check_street_encounter())
        self.assertEqual((m.haul, m.money, self.game.bank_balance), (0, 0, 400))
        self.assertIn('cash', self.game.message)

    def test_bandit_takes_one_category_not_both(self):
        m = self.game.miner
        m.haul, m.money = 45, 500
        with patch.object(self.game.rng, 'random', side_effect=[0, 0]):
            self.game._check_street_encounter()
        self.assertEqual((m.haul, m.money), (0, 500))
        self.game.dismiss_encounter()
        self.game.encounter_cooldown = 0
        m.haul, m.money = 45, 500
        with patch.object(self.game.rng, 'random', side_effect=[0, .99]):
            self.game._check_street_encounter()
        self.assertEqual((m.haul, m.money), (45, 0))

    def test_risk_increases_eastward(self):
        self.game.miner.haul = 20
        self.game.miner.money = 0
        self.game.miner.x = 0
        with patch.object(self.game.rng, 'random', return_value=.01):
            self.assertFalse(self.game._check_street_encounter())
        self.game.miner.x = SHAFT
        with patch.object(self.game.rng, 'random', return_value=.01):
            self.assertTrue(self.game._check_street_encounter())
        self.assertEqual(self.game.encounter_kind, 'bandit')

    def test_no_encounters_underground_or_in_legacy_games(self):
        self.game.miner.haul = 30
        with patch.object(self.game.rng, 'random', return_value=0):
            self.game.miner.y = 3
            self.assertFalse(self.game._check_street_encounter())
            self.game.miner.y = 1
            self.game.town_layout = 'legacy'
            self.assertFalse(self.game._check_street_encounter())

    def test_cooldown_blocks_repeat_events(self):
        m = self.game.miner
        m.haul = 30
        with patch.object(self.game.rng, 'random', return_value=0):
            self.assertTrue(self.game._check_street_encounter())
            self.assertFalse(self.game._check_street_encounter())
            self.assertTrue(self.game.dismiss_encounter())
            self.assertFalse(self.game.dismiss_encounter())
            m.haul = 40
            for _ in range(24):
                self.assertFalse(self.game._check_street_encounter())
            self.assertTrue(self.game._check_street_encounter())

    def test_horizontal_surface_walk_can_trigger_encounter(self):
        m = self.game.miner
        m.x, m.y, m.money = 31, 1, 300
        with patch.object(self.game.rng, 'random', side_effect=[.9, 0]):
            self.assertTrue(self.game.try_move(1, 0))
        self.assertEqual(m.x, 32)
        self.assertEqual(self.game.state, 'encounter')
        self.assertFalse(self.game.try_move(1, 0))
        self.assertTrue(self.game.dismiss_encounter())

    def test_encounter_state_is_transient_and_saves_still_work(self):
        self.game.miner.haul = 20
        with patch.object(self.game.rng, 'random', return_value=0):
            self.game._check_street_encounter()
        self.assertTrue(self.game.dismiss_encounter())
        saved = self.game.to_dict()
        loaded = Game.from_dict(saved)
        self.assertEqual(loaded.to_dict(), saved)
        self.assertIsNone(loaded.encounter_kind)
        self.assertEqual(loaded.encounter_cooldown, 0)


if __name__ == '__main__':
    unittest.main()
