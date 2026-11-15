"""Frontier economy, legacy compatibility and surface spacing regression tests."""
import copy
import unittest
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'python'))
from miners_claim.engine import Game, SHAFT, WIN_GOAL
from miners_claim.townplan import buildings, near, shaft


class FrontierTownTests(unittest.TestCase):
    def setUp(self):
        self.g = Game(seed=91)
        self.g.state = 'mine'

    def test_order_and_open_space_between_businesses_and_mine(self):
        plots = buildings()
        self.assertEqual([x.name for x in plots],
                         ['mercantile', 'bank', 'assay', 'saloon'])
        for a, b in zip(plots, plots[1:]):
            self.assertGreaterEqual(b.west - a.east, 3)
        self.assertGreaterEqual(shaft() - plots[-1].east, 16)
        self.assertEqual(SHAFT, shaft())
        self.assertEqual(self.g.world[3][SHAFT], 13)

    def test_navigable_store_bank_assay_and_saloon(self):
        for name, enter in [('mercantile', self.g.enter_store),
                            ('bank', self.g.enter_bank),
                            ('assay', self.g.enter_assay),
                            ('saloon', self.g.enter_saloon)]:
            for location in buildings():
                if location.name != name:
                    continue
                self.g.state = 'mine'
                self.g.miner.x, self.g.miner.y = location.west, 1
                self.assertTrue(enter(), name)
                self.assertNotEqual(self.g.state, 'mine')
                self.g.state = 'mine'
                self.g.miner.x = max(0, location.west - 1)
                self.assertFalse(enter(), 'off building edge ' + name)
                self.g.state = 'mine'
                break
            else:
                self.fail('Missing building ' + name)

    def test_bank_deposit_withdraw_conserves_value(self):
        self.g.miner.x = 17
        self.assertTrue(self.g.enter_bank())
        initial = self.g.miner.money + self.g.bank_balance
        self.assertEqual(self.g.deposit(60), 60)
        self.assertEqual((self.g.miner.money, self.g.bank_balance), (90,60))
        self.assertEqual(self.g.deposit(100), 0)
        self.assertEqual(self.g.withdraw(20), 20)
        self.assertEqual(self.g.withdraw(9999), 0)
        self.assertEqual((self.g.miner.money, self.g.bank_balance), (110,40))
        self.assertEqual(self.g.miner.money + self.g.bank_balance, initial)
        self.assertEqual(self.g.deposit(-3), 0)
        self.assertEqual(self.g.withdraw(0), 0)

    def test_bank_counts_for_score_win_and_prevents_premature_bankruptcy(self):
        self.g.miner.x = 17
        self.assertTrue(self.g.enter_bank())
        self.g.miner.money = WIN_GOAL
        self.assertEqual(self.g.deposit(100),100)
        self.assertEqual(self.g.state,'winner')
        self.assertEqual(self.g.final_score,WIN_GOAL)
        other=Game(seed=91)
        other.state='mine'
        other.miner.money = 0
        other.bank_balance = 5
        other._check_gameover()
        self.assertEqual(other.state,'mine')

    def test_no_remote_bank_or_saloon(self):
        self.g.miner.x, self.g.miner.y = 70, 1
        self.assertFalse(self.g.enter_bank())
        self.assertFalse(self.g.enter_saloon())
        self.assertEqual(self.g.deposit(10),0)
        self.assertFalse(self.g.buy_drink())

    def test_saloon_drink_and_cards(self):
        self.g.miner.x = 44
        self.assertTrue(self.g.enter_saloon())
        before = self.g.miner.money
        self.assertTrue(self.g.buy_drink())
        self.assertEqual((self.g.miner.money,self.g.miner.water),(before-5,1))
        before = self.g.miner.money
        result=self.g.play_cards()
        self.assertIn(result, (-10,0,10))
        self.assertEqual(self.g.miner.money-before,result)
        self.g.miner.money=0
        self.assertEqual(self.g.play_cards(),0)
        self.assertFalse(self.g.buy_drink())

    def test_new_save_round_trip_preserves_bank_and_layout(self):
        self.g.bank_balance=35
        self.g.miner.money=115
        self.g.state='bank'
        result=Game.from_dict(self.g.to_dict())
        self.assertEqual(result.to_dict(),self.g.to_dict())
        self.assertEqual((result.town_layout,result.bank_balance),('frontier',35))
        bad=self.g.to_dict()
        bad['bank_balance']=-1
        with self.assertRaises(ValueError):Game.from_dict(bad)
        bad=self.g.to_dict()
        bad['town_layout']='unknown'
        with self.assertRaises(ValueError):Game.from_dict(bad)

    def test_pre_frontier_save_remains_legacy(self):
        old=self.g.to_dict()
        old.pop('town_layout')
        old.pop('bank_balance')
        old['state']='mine'
        legacy=Game.from_dict(old)
        self.assertEqual((legacy.town_layout,legacy.bank_balance),('legacy',0))
        legacy.miner.x=13
        self.assertTrue(legacy.enter_assay())
        self.assertFalse(legacy.enter_bank())
        self.assertFalse(near('legacy','saloon',20,1))


if __name__ == '__main__':
    unittest.main()
