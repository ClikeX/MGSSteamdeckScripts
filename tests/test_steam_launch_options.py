from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "util"))

from steam_launch_options import VdfError, update_launch_options, write_updated_file


VDF = '''"UserLocalConfigStore"
{
\t"Software"
\t{
\t\t"Valve"
\t\t{
\t\t\t"Steam"
\t\t\t{
\t\t\t\t"apps"
\t\t\t\t{
\t\t\t\t\t"2131630"
\t\t\t\t\t{
\t\t\t\t\t\t"LaunchOptions"\t\t"-novid %command% --extra"
\t\t\t\t\t}
\t\t\t\t}
\t\t\t}
\t\t}
\t}
}
'''


class SteamLaunchOptionsTests(unittest.TestCase):
    def test_merges_overrides_and_preserves_arguments(self) -> None:
        updated, old, new, changed = update_launch_options(
            VDF, "2131630", "dinput8=n,b;d3d11=n,b"
        )
        self.assertTrue(changed)
        self.assertEqual("-novid %command% --extra", old)
        self.assertIn('WINEDLLOVERRIDES=\\"dinput8=n,b;d3d11=n,b\\"', updated)
        self.assertIn("-novid %command% --extra", new)

    def test_merges_existing_unrelated_override(self) -> None:
        source = VDF.replace(
            "-novid %command% --extra",
            'WINEDLLOVERRIDES=\\"dxgi=n,b\\" %command% --extra',
        )
        updated, _, new, changed = update_launch_options(
            source, "2131630", "winmm=n,b"
        )
        self.assertTrue(changed)
        self.assertIn("dxgi=n,b;winmm=n,b", new)
        self.assertIn("--extra", updated)

    def test_replaces_order_for_requested_dll_only(self) -> None:
        source = VDF.replace(
            "-novid %command% --extra",
            'WINEDLLOVERRIDES=\\"winmm=b;dxgi=n,b\\" %command%',
        )
        _, _, new, _ = update_launch_options(source, "2131630", "winmm=n,b")
        self.assertIn("winmm=n,b", new)
        self.assertIn("dxgi=n,b", new)
        self.assertNotIn("winmm=b;", new)

    def test_adds_new_app_entry(self) -> None:
        updated, old, new, changed = update_launch_options(
            VDF, "2492670", "wininet=n,b;winhttp=n,b"
        )
        self.assertTrue(changed)
        self.assertIsNone(old)
        self.assertIn('"2492670"', updated)
        self.assertIn("wininet=n,b;winhttp=n,b", new)

    def test_noop_when_already_set(self) -> None:
        first, _, _, _ = update_launch_options(VDF, "2131630", "dinput8=n,b")
        second, _, _, changed = update_launch_options(
            first, "2131630", "dinput8=n,b"
        )
        self.assertFalse(changed)
        self.assertEqual(first, second)

    def test_rejects_malformed_vdf(self) -> None:
        with self.assertRaises(VdfError):
            update_launch_options('"broken"', "2131630", "dinput8=n,b")

    def test_write_creates_backup(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "localconfig.vdf"
            path.write_text(VDF, encoding="utf-8")
            updated, _, _, _ = update_launch_options(
                VDF, "2131630", "dinput8=n,b"
            )
            backup = Path(directory) / "backup.vdf"
            result = write_updated_file(path, updated, backup)
            self.assertEqual(backup, result)
            self.assertEqual(VDF, backup.read_text(encoding="utf-8"))
            self.assertEqual(updated, path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
