# Metal Gear Solid 2 Installer

Installs **MGSHDFix** and the **MGS2 Community Bugfix Compilation** for
**Metal Gear Solid 2: Master Collection Version** (Steam AppID `2131640`) on
Steam Deck or desktop Linux.

## Usage

```bash
./installers/mgs2/install-mgs2.bash
```

Use `--path PATH` for a manually selected game directory, `--zip PATH` for an
offline MGSHDFix archive, and `--community-bugfix-zip PATH` for an offline
Community Bugfix base archive. Run `--help` for the complete CLI.

## Installed components

| Component | Default | Source |
|---|---|---|
| MGSHDFix | Yes | [GitHub Releases](https://github.com/ShizCalev/MGSHDFix/releases) |
| MGS2 Community Bugfix Compilation - Base | Yes | [GitHub Releases](https://github.com/ShizCalev/MGS2-Community-Bugfix-Compilation/releases) |
| MGS2 Community Bugfix Compilation - 2x texture add-on | Optional | Same Community Bugfix release |
| MGS2 Community Bugfix Compilation - 4x texture add-on | Optional | Same Community Bugfix release |

Use `--no-community-bugfix` for MGSHDFix-only installs.

Optional texture add-ons:

- `--textures-2x`
- `--textures-4x`
- `--textures-2x-zip PATH`
- `--textures-4x-zip PATH`

Only one texture add-on may be selected at a time. The 4x GitHub release is
published as multipart `.zip.001`, `.zip.002`, ... assets; the installer
downloads and assembles those parts automatically before validation. The
`--textures-*-zip` and `--textures-*-version` options also select that add-on.

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

The Community Bugfix base installs:

- `plugins/MGS2-Community-Bugfix-Compilation.asi`
- `plugins/MGS2-Community-Bugfix-Compilation.ini`

`MGSHDFix.settings` is user-generated and is never replaced or removed by this
installer. `MGS2-Community-Bugfix-Compilation.ini` is preserved by default; if
release defaults change, the installer writes
`plugins/MGS2-Community-Bugfix-Compilation.ini.new`. Use `--reset-ini` to back
up and replace the live Community Bugfix INI with the release defaults.

The installer also writes a mod-order note at:

```text
<game>/.mgs-installer/mgs2communitybugfix/mod-order.txt
```

Recommended load order:

1. MGSHDFix
2. Knight_Killer's MGS2 Better Audio Mod
3. MGS2 Community Bugfix Compilation - Base
4. MGS2 Community Bugfix Compilation - AI Upscaled Texture Add-on
5. MGS2 Demastered Texture Pack
6. All other mods

The installer always applies the Community Bugfix base before an optional 2x or
4x texture add-on so direct installs keep the required overwrite order.

## State and backups

Tracked state is stored under:

```text
<game>/.mgs-installer/mgshdfix/
<game>/.mgs-installer/mgs2communitybugfix/
<game>/.mgs-installer/mgs2communitybugfix2x/
<game>/.mgs-installer/mgs2communitybugfix4x/
```

MGSHDFix release `logs/` content is excluded. Files from older root-level
MGSHDFix layouts are removed during tracked updates so they cannot conflict with
the current `plugins/`, `wininet.dll`, and `winhttp.dll` layout.

## Uninstall

```bash
./installers/mgs2/install-mgs2.bash --uninstall
```

Only tracked files are removed, backed-up originals are restored, the
Community Bugfix mod-order note is removed, and `MGSHDFix.settings` is
preserved. Remove the DLL overrides from Steam afterward if no other mod
requires them.

## Requirements

- Steam Deck or desktop Linux
- Bash 5, Python 3, and `curl`
- Protontricks to run the MGSHDFix configuration tool on Linux

The installer downloads published release assets only. The repository's
`mods/` directory is not used as an install source.
