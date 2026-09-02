# Copilot instructions

## Commands

The repository requires Bash 5+, Python 3, `curl`, and Linux/SteamOS behavior.
Installer integration tests also create local fixtures with `zip`.

```bash
# Run the complete Python and Bash suite
python3 tests/run.py

# Run one Bash test file
bash -e tests/test-payload.bash

# Run one Python test file
python3 tests/test_archive.py

# Run one Python test method
python3 -m unittest tests.test_archive.ArchiveTests.test_rejects_parent_traversal

# Syntax-check every tracked Bash file
git ls-files -z '*.bash' | xargs -0 -n1 bash -n

# Byte-compile every tracked Python file
git ls-files -z '*.py' | xargs -0 python3 -m py_compile
```

Run commands from the repository root. There is no dependency installation
step for the Python utilities; they are standard-library-only.

## Architecture

- `installers/<game>/install-<game>.bash` files are the user-facing
  entrypoints. They use `set -euo pipefail`, resolve paths from
  `${BASH_SOURCE[0]}`, initialize `util/installer-core.bash`, declare the
  game's AppID/marker, and dispatch common or game-specific operations.
- `util/installer-core.bash` is the shared orchestration boundary. It sources
  CLI, output, dependency, Steam, state, and payload helpers; resolves targets;
  manages temporary workspaces; resolves/downloads release assets; extracts
  archives; and delegates Steam launch-option editing.
- Component modules such as `util/mgsm2fix-installer.bash`,
  `util/mgshdfix-installer.bash`, `util/mgspatriotfix-installer.bash`, and
  `util/mgsvfix-installer.bash` own release selection and payload rules for a
  mod. Simple per-game installers configure one of these modules with
  `MGS_GAME_*` constants; multi-component workflows such as MGS3, MGS4, and
  MGSV TPP coordinate multiple modules themselves.
- `util/archive.py`, `release_*.py`, `release_assets.py`,
  `steam_launch_options.py`, and `patriot_settings.py` own structured or
  safety-sensitive processing. Bash invokes these as standalone CLIs rather
  than implementing ZIP, JSON, or VDF parsing itself.
- `util/payload.bash` validates and copies a component payload.
  `util/install-state.bash` records ownership in
  `<target>/.mgs-installer/<component>/files.txt`, stores original files under
  the component's `backup/` tree, supports recognized legacy state, and drives
  uninstall/restore.
- Steam discovery flows through `util/steam-libraries.bash` and the sourceable
  `util/steam-path-from-appid.bash`. Launch-option updates flow through
  `util/steam_launch_options.py`, which preserves unrelated options and backs
  up `localconfig.vdf`.
- Top-level `installers/install-*.bash` files are compatibility wrappers. They
  translate supported legacy flags and delegate to per-game installers; they
  must not reintroduce independent install logic.
- `mods/` entries are pinned upstream submodules used only as reference
  material. Install payloads must come from published GitHub/Forgejo release
  assets or explicit local files, never from submodule build output.

## Repository-specific conventions

- Keep Bash and Python separated. Do not embed Python in Bash with heredocs,
  `python3 -c`, `python3 -`, or dynamically constructed snippets. Add a
  standalone executable Python utility with a documented CLI when structured
  processing is needed.
- All scripts must work regardless of the caller's current directory.
  Resolve repository-relative paths from the script's own `${BASH_SOURCE[0]}`
  location and canonicalize directories with `pwd -P`.
- Shared Bash functions and globals use the `mgs_`/`MGS_` prefixes. Sourceable
  utility files do not enable strict mode for their caller; executable
  installer and wrapper entrypoints do.
- Extend common CLI parsing through a game-specific parser passed to
  `mgs_cli_parse`. A recognized custom option must set `MGS_CLI_CONSUMED`;
  install-selection options must call `mgs_cli_mark_install_selection`, and
  exclusive maintenance modes must call `mgs_cli_set_exclusive`.
- Preserve the established status meanings: `64` for invalid CLI usage, `3`
  for not-found/not-tracked conditions, and `1` for operational failures.
- Release selection must use explicit, case-insensitive match/reject and
  extension rules. Reject source archives, drafts, unintended prereleases,
  unsafe URLs, and ambiguous asset sets rather than selecting the first match.
  Release resolver CLIs return tab-separated `tag`, `asset name`, and URL.
- Validate archives before installation. Reject empty ZIPs, absolute paths,
  traversal, drive-prefixed paths, and symlinks. Each component must define an
  expected payload marker and any known exclusions or stale paths.
- Never overwrite an unowned game file without backing it up first. A component
  update must treat files in its manifest as installer-owned, preserve
  unrelated files, and write the new manifest only after a successful install.
- User-editable INIs are preserved byte-for-byte by default. If release
  defaults change, write `<name>.new`; only `--reset-ini` replaces the
  canonical file after backing it up. `MGSHDFix.settings` remains
  user-generated and is excluded from payload ownership.
- Bash tests live in `tests/test-*.bash`, source
  `tests/helpers/testlib.bash`, create isolated data with `make_test_tmp`, and
  exercise installers with local ZIPs instead of network downloads. Python
  tests use `unittest` in `tests/test_*.py`. Add coverage in the language of
  the production unit being changed.
- Keep each per-game README synchronized with its installer's flags,
  components, launch options, configuration preservation, state location, and
  uninstall behavior. Update legacy-wrapper tests when compatibility mappings
  or translated options change.
