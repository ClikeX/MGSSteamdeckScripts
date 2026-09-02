# Metal Gear Solid: Peace Walker Installer

Installs MGSPatriotFix for **Metal Gear Solid: Peace Walker** (Steam AppID
`2492660`) on Steam Deck or desktop Linux.

## Usage

```bash
./installers/mgspw/install-mgspw.bash
```

Use `--path PATH` for a manually selected game root or `--zip PATH` for an
offline Peace Walker release archive. Run `--help` for the complete CLI.

## Installed component

| Component | Default | Source |
|---|---|---|
| MGSPatriotFix | Yes | [GitHub Releases](https://github.com/ShizCalev/MGSPatriotFix/releases) |

The installer explicitly selects the Peace Walker release asset rather than
the separate MGS4 package. MGSPatriotFix can skip launch screens, force higher
resolution settings, and correct GPU selection. The installer does not choose
those gameplay or display settings.

## Steam launch options

```text
WINEDLLOVERRIDES="wininet=n,b;winhttp=n,b" %command%
```

With Steam completely closed, merge these options without discarding unrelated
arguments:

```bash
./installers/mgspw/install-mgspw.bash --set-launch-options
```

Use `--user ACCOUNT_ID` when several Steam accounts are present.

## Configuration

Run `MGSPatriotFix Config Tool.exe` to configure the fix. On Steam Deck/Linux,
the tool requires Protontricks. Select any game prefix when prompted. If no
prefix appears, add the tool as a non-Steam game and launch it through Steam
once.

Complete default settings can instead be generated without the GUI:

```bash
./installers/mgspw/install-mgspw.bash --write-settings
```

An existing `MGSPatriotFix.settings` is never overwritten unless `--yes` is
also supplied. Installation, updates, and uninstall preserve this file.
MGSPatriotFix provides no release INI, so `--reset-ini` is rejected.

State and backups are stored under
`<game>/.mgs-installer/mgspatriotfix/`. Legacy `.mgspatriotfix-files.txt` and
`.mgspatriotfix-backup/` installs remain recognizable.

## Uninstall

```bash
./installers/mgspw/install-mgspw.bash --uninstall
```

Only tracked files are removed, backed-up originals are restored, and settings
are preserved. Remove the DLL overrides from Steam afterward if no other mod
requires them.

## Requirements

- Steam Deck or desktop Linux
- Steam or Flatpak Steam
- Bash 5, Python 3, and `curl`
- Protontricks only when using the graphical configuration tool

The installer downloads published release assets only. The repository's
`mods/` directory is not used as an install source.
