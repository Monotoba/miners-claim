"""Static checks for the QB64 v0.3.0 port; not runtime/compile certification."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'qb64' / 'MinersClaim_QB64_v0.3.0.bas'
TEXT = SRC.read_text('utf-8')


def block(name):
    match = re.search(r'(?ms)^SUB ' + re.escape(name) + r'(?:\s|\().*?^END SUB\s*$', TEXT)
    if match is None:
        raise AssertionError(f'Missing routine {name}')
    return match.group(0)


class QB64PortStaticTests(unittest.TestCase):
    def test_unique_routine_names_and_balanced_blocks(self):
        sub_names = re.findall(r'(?m)^SUB (\w+)', TEXT)
        function_names = re.findall(r'(?m)^FUNCTION (\w+)', TEXT)
        self.assertEqual(len(sub_names), len(set(sub_names)))
        self.assertEqual(len(function_names), len(set(function_names)))
        self.assertEqual(len(sub_names), len(re.findall(r'(?m)^END SUB\s*$', TEXT)))
        self.assertEqual(len(function_names), len(re.findall(r'(?m)^END FUNCTION\s*$', TEXT)))

    def test_default_window_fits_below_1200p_with_desktop_decorations(self):
        self.assertIn('CONST SCRW = 320', TEXT)
        self.assertIn('CONST SCRH = 200', TEXT)
        self.assertIn('CONST SCREEN_SCALE = 5', TEXT)
        self.assertIn('CONST WINH = SCRH * SCREEN_SCALE', TEXT)
        self.assertIn('CONST MSGH = 16', TEXT)
        self.assertIn('SUB PresentFrame', TEXT)
        self.assertIn('_PUTIMAGE (0, 0)-(WINW - 1, WINH - 1)', TEXT)

    def test_footer_and_high_score_text_fit_logical_canvas(self):
        # QB64's default font is 8x16. Text starting at y=192 is
        # clipped by eight pixels on a 200-pixel logical screen.
        self.assertIn('CONST SCRH = 200', TEXT)
        self.assertIn('CONST MSGH = 32', TEXT)
        footer = block('DrawMessageBar')
        self.assertIn('_PRINTSTRING (2, SCRH - 16)', footer)
        self.assertIn('_PRINTSTRING (4, SCRH - MSGH)', footer)
        self.assertNotIn('SCRH - 13', footer)
        self.assertNotIn('SCRH - MSGH - 9', footer)
        scores = block('DrawHighScores')
        self.assertIn('_PRINTSTRING (6, SCRH - 16)', scores)
        self.assertNotIn('_PRINTSTRING (6, 192)', scores)
        self.assertIn('_PRINTSTRING (40, 168)', scores)
        assay = block('DrawAssay')
        self.assertIn('_PRINTSTRING (18, 183)', assay)
        self.assertNotIn('_PRINTSTRING (18, 184)', assay)
        self.assertIn('_PRINTSTRING (4, 82)', assay)
        self.assertNotIn('198 - 10', assay)

    def test_frontier_and_legacy_geography(self):
        for item in ('CONST CLAIM_SHAFT_X = 72', 'CONST LEGACY_SHAFT_X = 28',
                     'DrawFrontierBuilding 1, 11', 'DrawFrontierBuilding 15, 9',
                     'DrawFrontierBuilding 27, 11', 'DrawFrontierBuilding 41, 13',
                     'FUNCTION NearBank%', 'FUNCTION NearSaloon%'):
            with self.subTest(item=item):
                self.assertIn(item, TEXT)

    def test_economy_and_score_invariants(self):
        bank = block('HandleBankInput')
        self.assertIn('Miner.money = Miner.money - amount', bank)
        self.assertIn('BankBalance = BankBalance + amount', bank)
        self.assertIn('BankBalance = BankBalance - amount', bank)
        self.assertIn('Miner.money = Miner.money + amount', bank)
        self.assertIn('IF amount > Miner.money', bank)
        self.assertIn('IF amount > BankBalance', bank)
        self.assertIn('Miner.money + BankBalance >= WIN_GOAL', block('CheckWin'))
        self.assertIn('Miner.money + BankBalance + Miner.haul', block('BeginNameEntry'))
        saloon = block('HandleSaloonInput')
        self.assertIn('Miner.money = Miner.money + winnings', saloon)
        self.assertIn('Miner.water = Miner.water + 1', saloon)

    def test_bandit_threshold_and_west_east_probability(self):
        encounter = block('CheckStreetEncounter')
        for item in ('Miner.money > 300', 'Miner.money >= 300',
                     '.00005 + .00045 * frac * frac',
                     'Miner.haul = 0', 'Miner.money = 0',
                     'EncounterCooldown = 24', 'IF TownLegacy THEN EXIT SUB'):
            with self.subTest(item=item):
                self.assertIn(item, encounter)
        self.assertNotIn('BankBalance = 0', encounter)
        self.assertIn('IF Miner.y > SURFACE_Y THEN EXIT SUB', encounter)

    def test_hazards_and_cart_states(self):
        hazards = block('CheckAdjacentHazards')
        self.assertIn('HazardExposure >= 20', hazards)
        self.assertIn('HazardExposure >= 35', hazards)
        cart = block('UpdateCart')
        self.assertIn('CartMode = 2', cart)
        self.assertIn('CartMode = 0', cart)
        self.assertIn('CartMode = 1', block('HandleStoreInput'))
        self.assertIn('CartMode = 0', block('EnterAssayOffice'))

    def test_v3_save_header_and_legacy_compatibility(self):
        save = block('SaveGame')
        load = block('LoadGame')
        self.assertIn('MINERS_CLAIM_SAVE_V3', save)
        self.assertIn('INPUT #f, BankBalance', load)
        self.assertIn('INPUT #f, TownLegacy', load)
        self.assertIn('MINERS_CLAIM_SAVE_V1', load)
        self.assertIn('MINERS_CLAIM_SAVE_V2', load)
        self.assertIn('LEGACY_SAVE_FILE', load)
        self.assertIn('miners_claim_qb64_v030_save.txt', TEXT)

    def test_no_side_effects_to_archived_baseline(self):
        self.assertIn('OPTION _EXPLICIT', TEXT)
        self.assertIn('SUB ExplodeTNT', TEXT)
        self.assertIn('SUB PickupLooseLoot', TEXT)
        self.assertIn('SUB LoadHighScores', TEXT)
        self.assertIn('SUB SaveHighScores', TEXT)
        self.assertIn('SUB InitGame', TEXT)


if __name__ == '__main__':
    unittest.main()