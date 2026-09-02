# Metal Gear Solid Installer

Installs MGSM2Fix for **Metal Gear Solid: Master Collection Version**
(Steam AppID `2131630`) on Steam Deck or desktop Linux.

## Usage

```bash
./installers/mgs1/install-mgs1.bash
```

Use `--path PATH` for a manually selected game directory or `--zip PATH` for an
offline release archive. Run `--help` for the complete CLI.

## Installed component

| Component | Default | Source |
|---|---|---|
| MGSM2Fix | Yes | [GitHub Releases](https://github.com/nuggslet/MGSM2Fix/releases) |

MGSM2Fix provides widescreen support, borderless/windowed mode, deadzone
removal, launcher and logo skipping, Master Collection patch controls, Ketchup
PPF3 mod support, and debugging features. Configure those features in
`MGSM2Fix.ini`; the installer does not choose gameplay settings.

## Steam launch options

```text
WINEDLLOVERRIDES="dinput8=n,b;d3d11=n,b" %command%
```

With Steam completely closed, the installer can merge these options without
discarding unrelated arguments:

```bash
./installers/mgs1/install-mgs1.bash --set-launch-options
```

Use `--user ACCOUNT_ID` when several Steam accounts are present.

## Configuration and updates

If `MGSM2Fix.ini` is absent, the installer creates it from the selected
release. An existing INI is preserved byte-for-byte. Changed release defaults
are written to `MGSM2Fix.ini.new`.

Use `--reset-ini` during installation to back up and replace the existing INI
with stock defaults.

Installed paths and backups are stored under:

```text
<game>/.mgs-installer/mgsm2fix/
```

Legacy `.mgsm2fix-files.txt` and `.mgsm2fix-backup/` installs remain
recognizable for update and uninstall.

## Uninstall

```bash
./installers/mgs1/install-mgs1.bash --uninstall
```

Only tracked files are removed, and backed-up originals are restored. Remove
the MGSM2Fix DLL overrides from Steam afterward if no other mod requires them.

## Requirements

- Steam Deck or desktop Linux
- Steam or Flatpak Steam
- Bash 5, Python 3, and `curl`

The installer downloads published release assets only. The repository's
`mods/` directory is not used as an install source.
