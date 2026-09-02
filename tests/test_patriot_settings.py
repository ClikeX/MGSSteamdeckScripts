from __future__ import annotations

import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path

import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "util"))

from patriot_settings import settings_text, write_settings


class PatriotSettingsTests(unittest.TestCase):
    def test_peace_walker_defaults_use_game_specific_keys(self) -> None:
        content = settings_text("pw")
        self.assertIn("Button Icons (PW) = Keyboard", content)
        self.assertIn("Skip Launcher Splashscreens (PW) = Disabled", content)
        self.assertIn("Internal Resolution (PW) = Original", content)
        self.assertIn("Internal Upscaling (PW) = Original", content)
        self.assertIn("Cutscenes (PW) = Original", content)
        self.assertIn("Pause On Focus Loss = false", content)
        self.assertNotIn(" | Main Menu", content)

    def test_mgs4_defaults_use_mgs4_values(self) -> None:
        content = settings_text("mgs4")
        self.assertIn("Button Icons = AUTO", content)
        self.assertIn("Disabled | Game Start | Main Menu", content)

    def test_existing_file_requires_force(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "MGSPatriotFix.settings"
            destination.write_text("custom", encoding="utf-8")
            with redirect_stderr(StringIO()):
                self.assertEqual(
                    write_settings(destination, "pw", False, False),
                    1,
                )
            self.assertEqual(destination.read_text(encoding="utf-8"), "custom")

    def test_force_replaces_existing_file(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "MGSPatriotFix.settings"
            destination.write_text("custom", encoding="utf-8")
            with redirect_stdout(StringIO()):
                self.assertEqual(
                    write_settings(destination, "pw", True, False),
                    0,
                )
            self.assertIn(
                "Button Icons (PW) = Keyboard",
                destination.read_text(encoding="utf-8"),
            )


if __name__ == "__main__":
    unittest.main()
