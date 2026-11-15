"""Verify recovered archival source bytes have not changed."""
import hashlib
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {
    "MinersClaim_QB64.bas": "1d1e4c84c5807a045cc9e6e6caa8259321003f079aa7296dc594cdae87588f24",
    "MinersClaim_QB64_v23_tnt_fuse_blast.bas": "aa9c6f52e7af79cf21ca8f0fc5edf5f068843dcdea2c8a7bcb32c768f02dfc57",
    "MinersClaim_QB64_v29_simple_tnt_timer.bas": "9d20763bafbdb2c1b3fb038a791deb443d6a1f94679dd673f342cb4ea03cc8c3",
}

class OriginalSourceIntegrityTests(unittest.TestCase):
    def test_original_files_have_expected_hashes(self):
        for filename, expected in EXPECTED.items():
            with self.subTest(filename=filename):
                path = ROOT / "original-qb64" / filename
                self.assertTrue(path.is_file())
                digest = hashlib.sha256(path.read_bytes()).hexdigest()
                self.assertEqual(digest, expected)

if __name__ == "__main__":
    unittest.main()
