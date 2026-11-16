"""Static QB4.5 source-contract checks; not a Microsoft QB4.5 compilation test."""
import re
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'qb45' / 'MINER45.BAS'


class QuickBasic45SourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SRC.read_text('ascii')
        cls.lines = cls.text.splitlines()

    def block(self, name):
        m = re.search(r'(?ims)^SUB ' + name + r'\b[^\n]*\n.*?^END SUB\s*$', self.text)
        self.assertIsNotNone(m, name)
        return m.group(0)

    def test_source_is_dos_ascii_and_short_lines(self):
        self.assertTrue(all(len(line) <= 255 for line in self.lines))
        self.assertNotIn('\t', self.text)
        self.assertNotRegex(self.text, r'(?im)\bhex\$\s*=')
        self.assertGreater(len(self.lines), 600)

    def test_only_quickbasic_45_graphics_input(self):
        for forbidden in (r'\b_NEWIMAGE\b', r'\b_PRINTSTRING\b', r'\b_KEYDOWN\b',
                          r'\b_PUTIMAGE\b', r'\b_DISPLAY\b', r'\b_LIMIT\b',
                          r'\b_FILEEXISTS\b', r'\b_RGB32\b', r'\b_UNSIGNED\b'):
            self.assertNotRegex(self.text.upper(), forbidden)
        self.assertIn('SCREEN 13', self.text)
        self.assertIn('KEY OFF', self.text)
        self.assertIn('INKEY$', self.text)
        self.assertIn('LOCATE row, 1', self.text)

    def test_unique_declared_routines(self):
        routines = re.findall(r'(?im)^(SUB|FUNCTION)\s+([A-Z][A-Z0-9]*\$?&?%?)', self.text)
        self.assertEqual(len(routines), len(set(routines)))
        self.assertEqual(len(re.findall(r'(?im)^SUB\b', self.text)), len(re.findall(r'(?im)^END SUB$', self.text)))
        self.assertEqual(len(re.findall(r'(?im)^FUNCTION\b', self.text)), len(re.findall(r'(?im)^END FUNCTION$', self.text)))
        declared = re.findall(r'(?im)^DECLARE (SUB|FUNCTION)\s+([A-Z][A-Z0-9]*\$?&?%?)', self.text)
        self.assertEqual({(k.upper(), n.upper()) for k, n in routines},
                         {(k.upper(), n.upper()) for k, n in declared})

    def test_world_storage_and_exact_economy(self):
        for term in ('CONST MW = 128', 'CONST MH = 96', 'CONST SHAFT = 72',
                     'CONST TARGET = 1000000', 'STRING$(MW, CHR$(EMPTY))',
                     'STRING$(MW, CHR$(0))', 'MID$(W$(y), x + 1, 1)',
                     'MID$(L$(y), x + 1, 1)', 'HaulLimit& = 75',
                     'HaulLimit& = 300', 'Cash = 150', 'Lives = 5',
                     'OreValue& = 20', 'OreValue& = 12', 'OreValue& = 45'):
            with self.subTest(term=term): self.assertIn(term, self.text)

    def test_bank_and_bandit_rules(self):
        bank = self.block('BankKey')
        for term in ('Cash = Cash - amount&: Bank = Bank + amount&',
                     'Bank = Bank - amount&: Cash = Cash + amount&'):
            self.assertIn(term, bank)
        bandit = self.block('CheckRoad')
        for term in ('Cash >= 300', 'Cash > 300', 'Haul = 0', 'Cash = 0',
                     'PauseSteps = 24', '.00005! + .00045! * frac! * frac!'):
            self.assertIn(term, bandit)
        self.assertIn('Cash + Bank >= TARGET', self.block('CheckWin'))

    def test_dos_save_format_and_legacy_isolation(self):
        save = self.block('SaveMine')
        load = self.block('LoadMine')
        self.assertIn('MC45V1', save)
        self.assertIn('MC45V1', load)
        self.assertIn('MC45SAVE.DAT', self.text)
        self.assertNotIn('MINERS_CLAIM_SAVE_V3', save)
        self.assertIn('LEN(rowHex$) <> MW * 2', load)
        self.assertIn('LEN(rowHex$) <> MW', load)

    def test_25_line_screen_bottom_does_not_scroll(self):
        draw = self.block('DrawTextLine')
        self.assertIn('PRINT LEFT$(caption$ + SPACE$(39), 39);', draw)
        self.assertIn('DrawTextLine 25, 14, Message$', self.text)
        self.assertIn('DrawTextLine 24, 10, label$', self.text)
        self.assertIn('LOCATE row, 1', draw)

    def test_core_mining_loop_exists(self):
        for term in ('SUB GenerateMine', 'SUB MoveTo', 'SUB LoseLife',
                     'SUB CheckFall', 'SUB CheckExposure', 'SUB TriggerTNT',
                     'SUB BlastTNT', 'SUB PickLoot', 'SUB SellOre',
                     'SUB ShowMine', 'SUB SaloonKey', 'SUB NewGame'):
            self.assertIn(term, self.text)


if __name__ == '__main__':
    unittest.main()