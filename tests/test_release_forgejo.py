from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "util"))

from release_assets import ReleaseSelectionError, select_release_asset


class ForgejoReleaseTests(unittest.TestCase):
    def setUp(self) -> None:
        self.release = {
            "tag_name": "0.1.0",
            "draft": False,
            "prerelease": False,
            "assets": [
                {
                    "name": "MGSVFix_0.1.0.zip",
                    "browser_download_url": (
                        "https://codeberg.org/Lyall/MGSVFix/releases/download/"
                        "0.1.0/MGSVFix_0.1.0.zip"
                    ),
                },
                {
                    "name": "checksums.txt",
                    "browser_download_url": (
                        "https://codeberg.org/Lyall/MGSVFix/releases/download/"
                        "0.1.0/checksums.txt"
                    ),
                },
            ],
        }

    def test_selects_mgsvfix_zip(self) -> None:
        selected = select_release_asset(
            self.release,
            match=r"^MGSVFix",
            download_prefix=(
                "https://codeberg.org/Lyall/MGSVFix/releases/download/0.1.0/"
            ),
        )
        self.assertEqual("MGSVFix_0.1.0.zip", selected[1])

    def test_rejects_asset_outside_release(self) -> None:
        self.release["assets"][0]["browser_download_url"] = (
            "https://example.com/MGSVFix_0.1.0.zip"
        )
        with self.assertRaisesRegex(ReleaseSelectionError, "outside"):
            select_release_asset(
                self.release,
                match=r"^MGSVFix",
                download_prefix=(
                    "https://codeberg.org/Lyall/MGSVFix/releases/download/0.1.0/"
                ),
            )

    def test_rejects_missing_zip(self) -> None:
        self.release["assets"] = self.release["assets"][1:]
        with self.assertRaisesRegex(ReleaseSelectionError, "no eligible"):
            select_release_asset(self.release, match=r"^MGSVFix")


if __name__ == "__main__":
    unittest.main()
