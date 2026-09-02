from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "util"))

from release_assets import ReleaseSelectionError, load_release, select_release_asset
from release_github import _release_from_html


class GitHubReleaseTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tempdir.cleanup)
        self.path = Path(self.tempdir.name) / "release.json"
        self.release = {
            "tag_name": "v1.2.3",
            "draft": False,
            "prerelease": False,
            "assets": [
                {
                    "name": "MGSPatriotFix-MGS4-v1.2.3.zip",
                    "browser_download_url": (
                        "https://github.com/ShizCalev/MGSPatriotFix/"
                        "releases/download/v1.2.3/MGSPatriotFix-MGS4-v1.2.3.zip"
                    ),
                },
                {
                    "name": "MGSPatriotFix-PW-v1.2.3.zip",
                    "browser_download_url": (
                        "https://github.com/ShizCalev/MGSPatriotFix/"
                        "releases/download/v1.2.3/MGSPatriotFix-PW-v1.2.3.zip"
                    ),
                },
            ],
        }

    def select(self, **kwargs: object) -> tuple[str, str, str]:
        return select_release_asset(
            self.release,
            download_prefix=(
                "https://github.com/ShizCalev/MGSPatriotFix/"
                "releases/download/v1.2.3/"
            ),
            **kwargs,
        )

    def test_selects_mgs4_asset(self) -> None:
        selected = self.select(match="MGS4", reject=r"PW|PeaceWalker|Peace_Walker")
        self.assertEqual("MGSPatriotFix-MGS4-v1.2.3.zip", selected[1])

    def test_selects_peace_walker_asset(self) -> None:
        selected = self.select(
            match=r"PW|PeaceWalker|Peace_Walker", reject="MGS4"
        )
        self.assertEqual("MGSPatriotFix-PW-v1.2.3.zip", selected[1])

    def test_rejects_ambiguous_assets(self) -> None:
        with self.assertRaisesRegex(ReleaseSelectionError, "ambiguous"):
            self.select(match="MGSPatriotFix")

    def test_rejects_generated_source_archive(self) -> None:
        release = {
            "tag_name": "v1.0.0",
            "assets": [
                {
                    "name": "source-code.zip",
                    "browser_download_url": (
                        "https://github.com/example/mod/releases/download/"
                        "v1.0.0/source-code.zip"
                    ),
                }
            ],
        }
        with self.assertRaisesRegex(ReleaseSelectionError, "no eligible"):
            select_release_asset(release, match="source")

    def test_prerelease_requires_explicit_permission(self) -> None:
        self.release["prerelease"] = True
        with self.assertRaisesRegex(ReleaseSelectionError, "prerelease"):
            self.select(match="MGS4")
        selected = self.select(match="MGS4", allow_prerelease=True)
        self.assertEqual("v1.2.3", selected[0])

    def test_html_selection_ignores_other_repositories(self) -> None:
        release = _release_from_html(
            "ShizCalev/MGSPatriotFix",
            "v1.2.3",
            """
            <a href="/ShizCalev/MGSPatriotFix/releases/download/v1.2.3/MGS4.zip">
            <a href="/other/repo/releases/download/v1.2.3/evil.zip">
            """,
        )
        selected = select_release_asset(
            release,
            match="MGS4",
            download_prefix=(
                "https://github.com/ShizCalev/MGSPatriotFix/"
                "releases/download/v1.2.3/"
            ),
        )
        self.assertEqual("MGS4.zip", selected[1])

    def test_load_release_rejects_malformed_json(self) -> None:
        self.path.write_text("{", encoding="utf-8")
        with self.assertRaisesRegex(ReleaseSelectionError, "could not parse"):
            load_release(self.path)


if __name__ == "__main__":
    unittest.main()
