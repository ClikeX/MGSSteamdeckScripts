# Metal Gear Solid V: Ground Zeroes Installer

Installs MGSVFix for **Metal Gear Solid V: Ground Zeroes** (Steam AppID
`311340`) on Steam Deck or desktop Linux.

## Usage

```bash
./installers/mgsv-gz/install-mgsv-gz.bash
```

Use `--path PATH` for a manually selected game directory or `--zip PATH` for an
offline MGSVFix release archive. Run `--help` for the complete CLI.

## Installed component

| Component | Default | Source |
|---|---|---|
| MGSVFix | Yes | [Codeberg Releases](https://codeberg.org/Lyall/MGSVFix/releases) |

MGSVFix can skip intro screens, unlock framerate and resolution options,
correct ultrawide HUD and graphical effects, and adjust LOD distances.
Configure these features in `MGSVFix.ini`; the installer does not choose
gameplay or display settings.

Only Codeberg's Forgejo releases are used. The archived GitHub mirror and the
repository's checked-out source are not install sources.

## Steam launch options

```text
WINEDLLOVERRIDES="winmm=n,b" %command%
```

With Steam completely closed, merge this override without discarding unrelated
arguments:

```bash
./installers/mgsv-gz/install-mgsv-gz.bash --set-launch-options
```

Use `--user ACCOUNT_ID` when several Steam accounts are present.

## Configuration and updates

If `MGSVFix.ini` is absent, the installer creates it from the selected release.
An existing INI is preserved byte-for-byte, and changed defaults are written
to `MGSVFix.ini.new`.

Use `--reset-ini` during installation to back up and replace the existing INI
with stock defaults. Updates remove tracked loader files from obsolete
MGSVFix layouts.

State and backups are stored under:

```text
<game>/.mgs-installer/mgsvfix/
```

Legacy `.mgsvfix-manifest.txt` and `.mgsvfix-backup-*` state remains
recognizable for update and uninstall.

## Uninstall

```bash
./installers/mgsv-gz/install-mgsv-gz.bash --uninstall
```

Only tracked files are removed, and backed-up originals are restored. Remove
the `winmm` override from Steam afterward if no other mod requires it.

Infinite Heaven is a Phantom Pain-only workflow and is intentionally not
available from this installer.

## Requirements

- Steam Deck or desktop Linux
- Steam or Flatpak Steam
- Bash 5, Python 3, and `curl`

The installer downloads published release assets only. The repository's
`mods/` directory is not used as an install source.
