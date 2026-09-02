#!/usr/bin/env python3

from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TESTS = ROOT / "tests"


def run_python_tests() -> bool:
    suite = unittest.defaultTestLoader.discover(
        str(TESTS),
        pattern="test_*.py",
    )
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    return result.wasSuccessful()


def run_bash_tests() -> bool:
    success = True
    for test_file in sorted(TESTS.glob("test-*.bash")):
        print(f"\n# {test_file.name}", flush=True)
        result = subprocess.run(["bash", str(test_file)], check=False)
        success = result.returncode == 0 and success
    return success


def main() -> int:
    python_ok = run_python_tests()
    bash_ok = run_bash_tests()
    if not python_ok or not bash_ok:
        print("\nTest suite failed.", file=sys.stderr)
        return 1
    print("\nAll Python and Bash tests passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
