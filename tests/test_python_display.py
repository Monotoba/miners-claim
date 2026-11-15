"""Window scaling and viewport regression tests (no pygame dependency)."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'python'))
from miners_claim.display import choose_scale, viewport


class DisplayLayoutTests(unittest.TestCase):
    def test_scale_auto_selects_integer_fit(self):
        self.assertEqual(choose_scale((1920, 1080)), 4)
        self.assertEqual(choose_scale((3840, 2160)), 8)
        self.assertEqual(choose_scale((1280, 800)), 3)
        self.assertEqual(choose_scale((640, 480)), 1)

    def test_explicit_letterbox_without_distortion(self):
        self.assertEqual(viewport((1280, 800)), (0, 0, 1280, 800))
        self.assertEqual(viewport((1280, 720)), (160, 60, 960, 600))
        self.assertEqual(viewport((1000, 900)), (20, 150, 960, 600))

    def test_small_windows_scale_down_proportionally(self):
        self.assertEqual(viewport((160, 100)), (0, 0, 160, 100))
        self.assertEqual(viewport((200, 100)), (20, 0, 160, 100))

    def test_reject_invalid_dimensions(self):
        for bad in ((0, 400), (-100, 200), (320, 0)):
            with self.subTest(bad=bad):
                with self.assertRaises(ValueError):
                    viewport(bad)
                with self.assertRaises(ValueError):
                    choose_scale(bad)

    def test_nonstandard_resolutions_fit(self):
        for size in ((300, 200), (1366, 768), (2560, 1440), (4000, 2000), (300, 190)):
            x, y, w, h = viewport(size)
            self.assertGreater(w, 0)
            self.assertGreater(h, 0)
            self.assertGreaterEqual(x, 0)
            self.assertGreaterEqual(y, 0)
            self.assertLessEqual(x + w, size[0])
            self.assertLessEqual(y + h, size[1])
            self.assertAlmostEqual(w/h, 320/200, delta=0.02)


if __name__ == '__main__':
    unittest.main()
