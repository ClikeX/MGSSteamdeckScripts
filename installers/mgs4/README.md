# Metal Gear Solid 4 Installer

Installs MGSPatriotFix and optional components for **Metal Gear Solid 4: Guns
of the Patriots** (Steam AppID `2492670`) on Steam Deck or desktop Linux.

## Usage

```bash
./installers/mgs4/install-mgs4.bash
```

Run `--help` for every supported component and maintenance option.

## Components

| Component | Default | Source |
|---|---|---|
| MGSPatriotFix | Yes | [GitHub Releases](https://github.com/ShizCalev/MGSPatriotFix/releases) |
| MGSM2Fix for the MGS1 flashback | No, `--mgs1-flashback` | [GitHub Releases](https://github.com/nuggslet/MGSM2Fix/releases) |
| MGS4 Mod Loader | No, `--modloader` | [GitHub Releases](https://github.com/cipherxof/MGS4-ModLoader/releases) or `--modloader-file` |

The common `--zip` and `--version` options select MGSPatriotFix. Use
`--mgs1-flashback-zip` for an offline MGSM2Fix archive and
`--modloader-file` for a trusted Mod Loader `.asi` or ZIP.

Prereleases are not selected automatically. If MGS4 Mod Loader has no stable
binary release, download the desired release asset yourself and pass it with
`--modloader-file`. Source trees are never compiled or installed.

## Optional MGS1 flashback fix

MGSM2Fix is installed beside the nested `mgs1.exe`, not into the main game
root. Its `MGSM2Fix.ini` follows the common preservation rules: missing files
are created, edited files are preserved, new defaults use `.new`, and
`--reset-ini` explicitly replaces the file after backup.

## Optional Mod Loader

MGS4 Mod Loader is installed as `MGS4/scripts/MGS4ModLoader.asi` with
`MGS4ModLoader.ini` beside it. Existing INI files are preserved. The installer
creates `MGS4/mods/`, but never tracks, empties, or removes it. Put each mod in
its own directory below that folder.

## Steam launch options

The base MGSPatriotFix overrides are:

```text
WINEDLLOVERRIDES="wininet=n,b;winhttp=n,b" %command%
```

When flashback MGSM2Fix state exists, `--set-launch-options` also merges
`dinput8=n,b` and `d3d11=n,b`. The decision comes from current or legacy
persisted state, so the install-selection flag does not need to be repeated.

```bash
./installers/mgs4/install-mgs4.bash --set-launch-options
```

Use `--user ACCOUNT_ID` when several Steam accounts are present.

## PatriotFix settings

Run `MGSPatriotFix Config Tool.exe` to configure PatriotFix. Protontricks is
required for the tool on Linux. Complete defaults can instead be written with:

```bash
./installers/mgs4/install-mgs4.bash --write-settings
```

Existing settings require `--yes` before replacement and are preserved by
installation and uninstall.

## State and uninstall

PatriotFix and Mod Loader state lives below the MGS4 root's
`.mgs-installer/`. Flashback state lives beside the nested `mgs1.exe`.

```bash
./installers/mgs4/install-mgs4.bash --uninstall
```

Uninstall removes Mod Loader files first, then flashback MGSM2Fix, then
PatriotFix. Backed-up originals are restored. `MGS4/mods/` and everything in it
are always preserved.

## Requirements

- Steam Deck or desktop Linux
- Steam or Flatpak Steam
- Bash 5, Python 3, and `curl`
- Protontricks only when using the PatriotFix configuration tool

Only published release assets or explicit local files are installed. The
repository's `mods/` content is reference material only.
