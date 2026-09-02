# Metal Gear Solid 2 Installer

Installs MGSHDFix for **Metal Gear Solid 2: Master Collection Version** (Steam
AppID `2131640`) on Steam Deck or desktop Linux.

## Usage

```bash
./installers/mgs2/install-mgs2.bash
```

Use `--path PATH` for a manually selected game directory or `--zip PATH` for an
offline release archive. Run `--help` for the complete CLI.

## Installed component

| Component | Default | Source |
|---|---|---|
| MGSHDFix | Yes | [GitHub Releases](https://github.com/ShizCalev/MGSHDFix/releases) |

MGSHDFix provides custom-resolution and ultrawide support, HUD and window-mode
controls, launcher and logo skipping, controller improvements, visual fixes,
restored effects, performance fixes, and optional gameplay adjustments. The
installer installs the fix but does not choose those settings.

Release `logs/` content is excluded. Files from older root-level layouts are
removed during tracked updates so they cannot conflict with the current
`plugins/`, `wininet.dll`, and `winhttp.dll` layout.

## Steam launch options

```text
WINEDLLOVERRIDES="wininet=n,b;winhttp=n,b" %command%
```

With Steam completely closed, merge these options without discarding unrelated
arguments:

```bash
./installers/mgs2/install-mgs2.bash --set-launch-options
```

Use `--user ACCOUNT_ID` when several Steam accounts are present. Do not add a
`d3d11` override for current MGSHDFix releases.

## Game and mod configuration

In the game's launcher, leave **Internal Resolution** and **Internal
Upscaling** set to **Default / Original**. MGSHDFix handles resolution.

Run `plugins/MGSHDFix Config Tool.exe` to configure the fix and generate
`MGSHDFix.settings`. On Steam Deck/Linux, the tool requires Protontricks.
Select any game prefix when prompted. If no prefix appears, add the
configuration tool as a non-Steam game and launch it through Steam once.

`MGSHDFix.settings` is user-generated and is never replaced or removed by this
installer. MGSHDFix provides no release INI, so `--reset-ini` is intentionally
rejected.

State and backups are stored under:

```text
<game>/.mgs-installer/mgshdfix/
```

Legacy `.mgshdfix-files.txt` and `.mgshdfix-backup/` installs remain
recognizable for update and uninstall.

## Uninstall

```bash
./installers/mgs2/install-mgs2.bash --uninstall
```

Only tracked files are removed, backed-up originals are restored, and
`MGSHDFix.settings` is preserved. Remove the DLL overrides from Steam afterward
if no other mod requires them.

## Requirements

- Steam Deck or desktop Linux
- Steam or Flatpak Steam
- Bash, Python 3, and `curl`
- Protontricks to run the MGSHDFix configuration tool on Linux

The installer downloads published release assets only. The repository's
`mods/` directory is not used as an install source.
