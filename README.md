# MGS Steam Deck Installers

Per-game installers for community fixes used by Metal Gear titles on Steam
Deck and desktop Linux.

## Installers

| Game | AppID | Default components | Optional components |
|---|---:|---|---|
| [Metal Gear Solid](installers/mgs1/README.md) | `2131630` | MGSM2Fix | None |
| [Metal Gear Solid 2](installers/mgs2/README.md) | `2131640` | MGSHDFix | None |
| [Metal Gear Solid 3](installers/mgs3/README.md) | `2131650` | MGSHDFix, MGS3CrouchWalk | CrouchWalk may be disabled |
| [Metal Gear Solid 4](installers/mgs4/README.md) | `2492670` | MGSPatriotFix | Flashback MGSM2Fix, MGS4 Mod Loader |
| [Peace Walker](installers/mgspw/README.md) | `2492660` | MGSPatriotFix | None |
| [The Phantom Pain](installers/mgsv-tpp/README.md) | `287700` | MGSVFix | Guided Infinite Heaven workflow |
| [Ground Zeroes](installers/mgsv-gz/README.md) | `311340` | MGSVFix | None |
| [Vol. 1 Bonus Content](installers/mc-vol1-bonus/README.md) | `2306740` | MGSM2Fix | None |
| [Vol. 2 Bonus Content](installers/mc-vol2-bonus/README.md) | `3036720` | MGSM2Fix | None |

## Basic usage

Run the installer for one game:

```bash
./installers/mgs1/install-mgs1.bash
```

Installers resolve the game through its Steam AppID. `--path PATH` overrides
auto-detection, and `--zip PATH` uses a local release archive. Use `--help` on
an installer for its exact options.

Common operations include:

```bash
./installers/mgs1/install-mgs1.bash --list
./installers/mgs1/install-mgs1.bash --dry-run
./installers/mgs1/install-mgs1.bash --set-launch-options
./installers/mgs1/install-mgs1.bash --uninstall
```

Missing release-provided INIs are created. Existing INIs are never replaced
automatically; changed defaults are written beside them as `.new`. Use the
single `--reset-ini` flag when an installer has a selected INI-providing
component.

## Steam support

Detection supports native Steam, Flatpak Steam, the primary library, and
additional internal, microSD, or external libraries listed by Steam.
Launch-option editing preserves unrelated arguments and creates a backup of
`localconfig.vdf`. Steam should be closed before using
`--set-launch-options`.

## Download policy

Installers prefer published release assets:

- GitHub Releases for MGSM2Fix, MGSHDFix, MGS3CrouchWalk, MGSPatriotFix, and
  MGS4 Mod Loader;
- Codeberg Forgejo Releases for MGSVFix.

Stable releases are selected by default. Source archives, repository source
trees, and unintended prereleases are rejected. The `mods/` directory is
reference material only and is never used as an install source.

Infinite Heaven remains a guided workflow because Nexus Mods and the
GUI-only SnakeBite installer do not provide a supported headless release
installation path.

## Legacy commands

The old mod-centric scripts remain as transition wrappers and print a
deprecation warning. Prefer the per-game commands:

| Legacy selection | Replacement |
|---|---|
| `./installers/install-mgshdfix.bash --game mgs2` | `./installers/mgs2/install-mgs2.bash` |
| `./installers/install-mgshdfix.bash --game mgs3` | `./installers/mgs3/install-mgs3.bash` |
| `./installers/install-mgsm2.bash --game mgs1` | `./installers/mgs1/install-mgs1.bash` |
| `./installers/install-mgsm2.bash --game bonus1` | `./installers/mc-vol1-bonus/install-mc-vol1-bonus.bash` |
| `./installers/install-mgsm2.bash --game bonus2` | `./installers/mc-vol2-bonus/install-mc-vol2-bonus.bash` |
| `./installers/install-mgsm2.bash --game mgs4` | `./installers/mgs4/install-mgs4.bash --mgs1-flashback` |
| `./installers/install-mgspatriotfix.bash --game mgs4` | `./installers/mgs4/install-mgs4.bash` |
| `./installers/install-mgspatriotfix.bash --game pw` | `./installers/mgspw/install-mgspw.bash` |
| `./installers/install-mgsvfix.bash --game tpp` | `./installers/mgsv-tpp/install-mgsv-tpp.bash` |
| `./installers/install-mgsvfix.bash --game gz` | `./installers/mgsv-gz/install-mgsv-gz.bash` |

Legacy multi-game selections are rejected with the corresponding replacement
commands instead of silently modifying several games.

Wrappers translate `--replace-ini` to `--reset-ini` and `--crouch-zip` to
`--crouchwalk-zip`. The obsolete `--no-build` option is discarded because the
new MGS4 installer never builds from source.

For the MGS4 flashback component, legacy `--zip` becomes
`--mgs1-flashback-zip`. Legacy `-v`/`--version` pins are rejected because the
new MGS4 installer has no flashback-version option; use a specific local
release asset with `--mgs1-flashback-zip` when pinning is required.

The legacy MGS4 flashback-only uninstall is rejected rather than delegated:
the new MGS4 `--uninstall` intentionally removes every tracked MGS4 component.
Use the MGS4 `--list` operation and review its README before an all-component
uninstall.

## Requirements

- Bash 5 or newer
- Python 3
- `curl`
- Steam Deck or desktop Linux

Python-dependent functionality is implemented as standalone Python programs.
Bash scripts never embed Python source.
