"""Regression tests for readable UI font, contextual legend and cart rules."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'python'))
from miners_claim.bitmapfont import FONT, PixelFont, glyph
from miners_claim.context import legend, returning_with_wheelbarrow
from miners_claim.engine import Game, GAS, GOLD, AIR


class BitmapFontTests(unittest.TestCase):
    def test_every_glyph_is_five_by_seven(self):
        for char, rows in FONT.items():
            with self.subTest(char=char):
                self.assertEqual(len(rows), 7)
                self.assertTrue(all(len(row) == 5 and set(row) <= {'0', '1'} for row in rows))

    def test_digits_dollar_and_letters_have_unique_legible_patterns(self):
        important = '0123456789$ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        for char in important:
            self.assertIn(char, FONT)
            self.assertTrue(any('1' in row for row in glyph(char)))
        self.assertEqual(len({glyph(char) for char in '0123456789$'}), 11)
        self.assertEqual(glyph('m'), glyph('M'))
        self.assertEqual(glyph('~'), glyph('?'))

    def test_advance_and_zero_width(self):
        self.assertEqual(PixelFont(1).size('$123'), (24, 8))
        self.assertEqual(PixelFont(2).size('ASSAY'), (60, 16))
        with self.assertRaises(ValueError):
            PixelFont(0)


class ContextTests(unittest.TestCase):
    def setUp(self):
        self.game = Game(seed=42)
        self.game.state = 'mine'
        self.game.miner.x = 40
        self.game.miner.y = 10
        self.game.world[10][40] = AIR

    def test_nearby_hazard_has_priority(self):
        self.game.world[10][41] = GAS
        self.game.world[9][40] = GOLD
        self.assertIn('GAS: TOXIC', legend(self.game))
        self.game.check_hazards()
        self.assertIn('GAS LEAK', legend(self.game))
        self.assertLessEqual(len(legend(self.game)), 52)

    def test_store_assay_and_surface_legends(self):
        self.game.state = 'store'
        self.assertIn('BUY', legend(self.game))
        self.game.state = 'assay'
        self.assertIn('SELL', legend(self.game))
        self.game.state = 'mine'
        self.game.miner.y = 1
        self.assertIn('M=MERCANTILE', legend(self.game))

    def test_loaded_wheelbarrow_only_when_returning(self):
        m = self.game.miner
        m.x, m.y, m.wheelbarrow, m.haul = 28, 1, 1, 55
        self.assertTrue(returning_with_wheelbarrow(m, -1))
        self.assertFalse(returning_with_wheelbarrow(m, 1))
        m.x = 5
        self.assertTrue(returning_with_wheelbarrow(m, 1))
        m.x = 20
        self.assertTrue(returning_with_wheelbarrow(m, -1))
        m.y = 3
        self.assertFalse(returning_with_wheelbarrow(m, -1))
        m.y, m.haul = 1, 0
        self.assertFalse(returning_with_wheelbarrow(m, -1))


if __name__ == '__main__':
    unittest.main()