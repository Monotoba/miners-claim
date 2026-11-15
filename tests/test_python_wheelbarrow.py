"""Regression tests for visually distinct wheelbarrow cargo and trading trips."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'python'))
from miners_claim.context import WheelbarrowCargo
from miners_claim.engine import Game


class WheelbarrowCargoTests(unittest.TestCase):
    def setUp(self):
        self.game = Game(seed=12)
        self.miner = self.game.miner
        self.miner.wheelbarrow = 1
        self.cart = WheelbarrowCargo()

    def test_supplies_after_purchasing_at_mercantile(self):
        self.cart.purchased(self.game.buy('food'))
        self.assertEqual(self.miner.food, 1)
        self.game.state = 'mine'
        self.cart.left_mercantile(self.miner)
        self.cart.update(self.miner)
        self.assertEqual(self.cart.cargo, 'supplies')
        self.assertTrue(self.cart.should_draw(self.miner))

    def test_no_purchase_leaves_empty_cart(self):
        self.game.state = 'mine'
        self.cart.left_mercantile(self.miner)
        self.assertEqual(self.cart.cargo, 'empty')
        self.assertTrue(self.cart.should_draw(self.miner))

    def test_items_remain_in_mine_and_only_ore_leaves(self):
        self.cart.purchased(self.game.buy('food'))
        self.cart.purchased(self.game.buy('pickaxe'))
        self.cart.left_mercantile(self.miner)
        self.assertEqual(self.cart.cargo, 'supplies')
        self.miner.y = 3
        self.cart.update(self.miner)
        self.assertEqual(self.cart.cargo, 'empty')
        self.assertEqual((self.miner.food, self.miner.pickaxe), (1, 1))
        self.assertFalse(self.cart.should_draw(self.miner))
        self.miner.haul = 45
        self.miner.y = 1
        self.cart.update(self.miner)
        self.assertEqual(self.cart.cargo, 'ore')
        self.assertTrue(self.cart.should_draw(self.miner))

    def test_partial_sale_leaves_empty_cart_and_retains_unsold_value(self):
        self.miner.y = 3
        self.cart.update(self.miner)
        self.miner.haul = 70
        self.miner.y = 1
        self.cart.update(self.miner)
        self.assertEqual(self.cart.cargo, 'ore')
        self.game.state = 'assay'
        self.cart.entered_assay()
        self.assertEqual(self.game.sell(20), 20)
        self.assertEqual(self.miner.haul, 50)
        self.game.state = 'mine'
        self.cart.update(self.miner)
        self.assertEqual(self.cart.cargo, 'empty')
        self.assertTrue(self.cart.should_draw(self.miner))
        self.assertEqual(self.game.sell(10), 0)  # cannot sell outside ASSAY

    def test_full_sale_leaves_empty_cart(self):
        self.miner.haul = 45
        self.cart.cargo = 'ore'
        self.game.state = 'assay'
        self.cart.entered_assay()
        self.assertEqual(self.game.sell(45), 45)
        self.game.state = 'mine'
        self.cart.update(self.miner)
        self.assertEqual((self.miner.haul, self.cart.cargo), (0, 'empty'))

    def test_ore_load_only_on_return_from_mine(self):
        self.miner.haul = 50
        self.cart.update(self.miner)
        self.assertEqual(self.cart.cargo, 'empty')
        self.miner.y = 3
        self.cart.update(self.miner)
        self.miner.y = 1
        self.cart.update(self.miner)
        self.assertEqual(self.cart.cargo, 'ore')

    def test_cart_does_not_render_without_wheelbarrow(self):
        self.miner.wheelbarrow = 0
        self.cart.purchased(True)
        self.cart.left_mercantile(self.miner)
        self.assertEqual(self.cart.cargo, 'empty')
        self.assertFalse(self.cart.should_draw(self.miner))

    def test_failed_purchase_does_not_create_supplies(self):
        self.cart.purchased(False)
        self.cart.left_mercantile(self.miner)
        self.assertEqual(self.cart.cargo, 'empty')


if __name__ == '__main__':
    unittest.main()
