#!/usr/bin/env python3

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def settings_text(game: str) -> str:
    is_pw = game == "pw"
    icons_key = "Button Icons (PW)" if is_pw else "Button Icons"
    icons_value = "Keyboard" if is_pw else "AUTO"
    splash_key = (
        "Skip Launcher Splashscreens (PW)"
        if is_pw
        else "Skip Launcher Splashscreens"
    )
    splash_values = "Disabled | Game Start" if is_pw else "Disabled | Game Start | Main Menu"
    pw_settings = ""
    if is_pw:
        pw_settings = """Internal Resolution (PW) = Original
Internal Upscaling (PW) = Original
Cutscenes (PW) = Original
"""

    return f"""; MGSPatriotFix settings - equivalent to the config tool's defaults.
; Booleans accept true/false, 1/0, yes/no, on/off.

[Enhancements && Tweaks]
; 1-16. Values outside that range are clamped.
Anisotropic Filtering Level = 16
Disable Dynamic Resolution = false
Disable Motion Blur = false
Pause On Focus Loss = false

[Controller Settings]
Enable DualShock 3 Support = false
; MGS4: AUTO | Xbox | PlayStation 4 | PlayStation 5 | Nintendo Switch
; PW:   Keyboard | Xbox | PlayStation 4 | PlayStation 5 | Nintendo Switch
{icons_key} = {icons_value}

[Language Settings]
; Region eu pairs with en/fr/it/gr/sp/pt; region jp pairs with jp.
; An invalid pair silently falls back to eu/en.
Game Region = eu
Game Language = en

[Launcher and Splashscreens]
Skip Launcher = false
; {splash_values}
{splash_key} = Disabled
Skip In-Game Splashscreens = false
{pw_settings}

[System Specific Fixes]
; Windows-only; inert under Proton.
Disable Windows Fullscreen Optimization = false

[Update Notifications]
Check For MGSPatriotFix Updates = true
In-Game Update Notifications = true

[Debugging]
Debug Logging = false
"""


def write_settings(destination: Path, game: str, force: bool, dry_run: bool) -> int:
    if destination.exists() and not force:
        print(
            f"error: {destination} already exists; use --force to overwrite it",
            file=sys.stderr,
        )
        return 1
    if dry_run:
        print(f"would write {destination}")
        return 0

    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(settings_text(game), encoding="utf-8", newline="\n")
    print(f"wrote {destination}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Write a complete default MGSPatriotFix settings file."
    )
    parser.add_argument("destination", type=Path)
    parser.add_argument("--game", choices=("mgs4", "pw"), required=True)
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    return write_settings(args.destination, args.game, args.force, args.dry_run)


if __name__ == "__main__":
    raise SystemExit(main())
