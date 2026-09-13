from __future__ import annotations

import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "util"))

import release_github
from release_assets import (
    ReleaseSelectionError,
    load_release,
    select_release_asset,
    select_release_assets,
)
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

    def test_selects_all_matching_assets(self) -> None:
        release = {
            "tag_name": "3.0.0",
            "draft": False,
            "prerelease": False,
            "assets": [
                {
                    "name": "MGS2-Community-Bugfix-Compilation_4x_Upscaled_Addon_v3.0.0.zip.001",
                    "browser_download_url": (
                        "https://github.com/ShizCalev/MGS2-Community-Bugfix-Compilation/"
                        "releases/download/3.0.0/"
                        "MGS2-Community-Bugfix-Compilation_4x_Upscaled_Addon_v3.0.0.zip.001"
                    ),
                },
                {
                    "name": "MGS2-Community-Bugfix-Compilation_4x_Upscaled_Addon_v3.0.0.zip.002",
                    "browser_download_url": (
                        "https://github.com/ShizCalev/MGS2-Community-Bugfix-Compilation/"
                        "releases/download/3.0.0/"
                        "MGS2-Community-Bugfix-Compilation_4x_Upscaled_Addon_v3.0.0.zip.002"
                    ),
                },
                {
                    "name": "MGS2-Community-Bugfix-Compilation_Base_v3.0.0.zip",
                    "browser_download_url": (
                        "https://github.com/ShizCalev/MGS2-Community-Bugfix-Compilation/"
                        "releases/download/3.0.0/MGS2-Community-Bugfix-Compilation_Base_v3.0.0.zip"
                    ),
                },
            ],
        }
        selected = select_release_assets(
            release,
            match=r"4x.*Upscaled",
            extension=r"\.zip\.[0-9]{3}$",
            download_prefix=(
                "https://github.com/ShizCalev/MGS2-Community-Bugfix-Compilation/"
                "releases/download/3.0.0/"
            ),
        )
        self.assertEqual("3.0.0", selected[0])
        self.assertEqual(
            [
                "MGS2-Community-Bugfix-Compilation_4x_Upscaled_Addon_v3.0.0.zip.001",
                "MGS2-Community-Bugfix-Compilation_4x_Upscaled_Addon_v3.0.0.zip.002",
            ],
            [name for name, _ in selected[1]],
        )

    def test_select_release_assets_rejects_ambiguous_without_match(self) -> None:
        release = {
            "tag_name": "3.0.0",
            "draft": False,
            "prerelease": False,
            "assets": [
                {
                    "name": "part-a.zip",
                    "browser_download_url": (
                        "https://github.com/example/mod/releases/download/3.0.0/part-a.zip"
                    ),
                },
                {
                    "name": "part-b.zip",
                    "browser_download_url": (
                        "https://github.com/example/mod/releases/download/3.0.0/part-b.zip"
                    ),
                },
            ],
        }
        with self.assertRaisesRegex(ReleaseSelectionError, "ambiguous"):
            select_release_assets(release)

    def test_resolve_release_assets_honors_web_base(self) -> None:
        release = {
            "tag_name": "3.0.0",
            "draft": False,
            "prerelease": False,
            "assets": [
                {
                    "name": "pack.zip.001",
                    "browser_download_url": (
                        "https://downloads.example/owner/repo/releases/download/3.0.0/pack.zip.001"
                    ),
                },
                {
                    "name": "pack.zip.002",
                    "browser_download_url": (
                        "https://downloads.example/owner/repo/releases/download/3.0.0/pack.zip.002"
                    ),
                },
            ],
        }
        with mock.patch.object(release_github, "_fetch_json", return_value=release):
            tag, assets = release_github.resolve_release_assets(
                "owner/repo",
                match=r"pack",
                extension=r"\.zip\.[0-9]{3}$",
                web_base="https://downloads.example",
            )
        self.assertEqual("3.0.0", tag)
        self.assertEqual(
            [
                (
                    "pack.zip.001",
                    "https://downloads.example/owner/repo/releases/download/3.0.0/pack.zip.001",
                ),
                (
                    "pack.zip.002",
                    "https://downloads.example/owner/repo/releases/download/3.0.0/pack.zip.002",
                ),
            ],
            assets,
        )

    def test_main_all_prints_each_asset(self) -> None:
        with (
            mock.patch.object(
                release_github,
                "resolve_release_assets",
                return_value=(
                    "3.0.0",
                    [
                        ("pack.zip.001", "https://example.invalid/pack.zip.001"),
                        ("pack.zip.002", "https://example.invalid/pack.zip.002"),
                    ],
                ),
            ),
            mock.patch("sys.stdout", new_callable=io.StringIO) as stdout,
        ):
            status = release_github.main(["owner/repo", "--all"])
        self.assertEqual(0, status)
        self.assertEqual(
            "3.0.0\tpack.zip.001\thttps://example.invalid/pack.zip.001\n"
            "3.0.0\tpack.zip.002\thttps://example.invalid/pack.zip.002\n",
            stdout.getvalue(),
        )


if __name__ == "__main__":
    unittest.main()
