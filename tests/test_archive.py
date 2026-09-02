from __future__ import annotations

import stat
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "util"))

from archive import ArchiveError, extract_zip, payload_files, payload_root, validate_zip


class ArchiveTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tempdir.cleanup)
        self.root = Path(self.tempdir.name)

    def make_zip(self, name: str, entries: dict[str, bytes]) -> Path:
        path = self.root / name
        with zipfile.ZipFile(path, "w") as archive:
            for entry_name, content in entries.items():
                archive.writestr(entry_name, content)
        return path

    def test_extracts_and_unwraps_payload(self) -> None:
        archive = self.make_zip(
            "normal.zip",
            {
                "payload/mod.asi": b"MZ",
                "payload/config.ini": b"[Settings]\n",
            },
        )
        destination = self.root / "extract"
        extract_zip(archive, destination)
        root = payload_root(destination)
        self.assertEqual((destination / "payload").resolve(), root)
        self.assertEqual(["config.ini", "mod.asi"], payload_files(root))
        self.assertEqual(b"MZ", (root / "mod.asi").read_bytes())

    def test_rejects_parent_traversal(self) -> None:
        archive = self.make_zip("traversal.zip", {"../escape.dll": b"MZ"})
        with self.assertRaisesRegex(ArchiveError, "traverses"):
            validate_zip(archive)

    def test_rejects_absolute_path(self) -> None:
        archive = self.make_zip("absolute.zip", {"/absolute.dll": b"MZ"})
        with self.assertRaisesRegex(ArchiveError, "absolute"):
            validate_zip(archive)

    def test_rejects_symlink(self) -> None:
        path = self.root / "symlink.zip"
        entry = zipfile.ZipInfo("link")
        entry.create_system = 3
        entry.external_attr = (stat.S_IFLNK | 0o777) << 16
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr(entry, "../outside")
        with self.assertRaisesRegex(ArchiveError, "symbolic links"):
            validate_zip(path)

    def test_rejects_empty_zip(self) -> None:
        path = self.root / "empty.zip"
        with zipfile.ZipFile(path, "w"):
            pass
        with self.assertRaisesRegex(ArchiveError, "empty"):
            validate_zip(path)

    def test_rejects_non_zip(self) -> None:
        path = self.root / "not.zip"
        path.write_text("not a zip", encoding="utf-8")
        with self.assertRaisesRegex(ArchiveError, "not a valid"):
            validate_zip(path)

    def test_cli_reports_relative_files(self) -> None:
        payload = self.root / "payload"
        (payload / "nested").mkdir(parents=True)
        (payload / "nested" / "file.txt").write_text("value", encoding="utf-8")
        result = subprocess.run(
            [sys.executable, str(ROOT / "util" / "archive.py"), "files", str(payload)],
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertEqual("nested/file.txt\n", result.stdout)


if __name__ == "__main__":
    unittest.main()
