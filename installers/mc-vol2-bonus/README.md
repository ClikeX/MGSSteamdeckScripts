# Master Collection Vol. 2 Bonus Content Installer

Installs MGSM2Fix for **Metal Gear Solid: Master Collection Vol. 2 Bonus
Content** (Steam AppID `3036720`) on Steam Deck or desktop Linux. This title
contains **Metal Gear Solid: Ghost Babel**.

## Usage

```bash
./installers/mc-vol2-bonus/install-mc-vol2-bonus.bash
```

Use `--path PATH` for a manually selected game directory or `--zip PATH` for an
offline release archive. Run `--help` for the complete CLI.

## Installed component

| Component | Default | Source |
|---|---|---|
| MGSM2Fix | Yes | [GitHub Releases](https://github.com/nuggslet/MGSM2Fix/releases) |

MGSM2Fix provides display, input, launcher, patch, and debugging improvements.
Configure those features in `MGSM2Fix.ini`; the installer does not choose
gameplay settings.

## Steam launch options

```text
WINEDLLOVERRIDES="dinput8=n,b;d3d11=n,b" %command%
```

With Steam completely closed, merge these options without discarding unrelated
arguments:

```bash
./installers/mc-vol2-bonus/install-mc-vol2-bonus.bash --set-launch-options
```

Use `--user ACCOUNT_ID` when several Steam accounts are present.

## Configuration and updates

If `MGSM2Fix.ini` is absent, the installer creates it from the selected
release. An existing INI is preserved byte-for-byte, and changed defaults are
written to `MGSM2Fix.ini.new`. Use `--reset-ini` to back up and replace the
existing INI.

State and backups are stored under `<game>/.mgs-installer/mgsm2fix/`. Legacy
`.mgsm2fix-files.txt` and `.mgsm2fix-backup/` installs remain recognizable.

## Uninstall

```bash
./installers/mc-vol2-bonus/install-mc-vol2-bonus.bash --uninstall
```

Only tracked files are removed, and backed-up originals are restored. Remove
the DLL overrides from Steam afterward if no other mod requires them.

## Requirements

- Steam Deck or desktop Linux
- Steam or Flatpak Steam
- Bash 5, Python 3, and `curl`

The installer downloads published release assets only. The repository's
`mods/` directory is not used as an install source.
