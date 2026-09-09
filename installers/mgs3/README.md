# Metal Gear Solid 3 Installer

Installs MGSHDFix and MGS3CrouchWalk for **Metal Gear Solid 3: Master
Collection Version** (Steam AppID `2131650`) on Steam Deck or desktop Linux.

## Usage

```bash
./installers/mgs3/install-mgs3.bash
```

MGSHDFix and CrouchWalk are installed by default. Use `--no-crouchwalk` for
MGSHDFix only. Add `--qcamo` to install quick-camouflage support. The common
`--zip` and `--version` options select the MGSHDFix source; use
`--crouchwalk-zip` or `--crouchwalk-version` for CrouchWalk, and
`--qcamo-zip` or `--qcamo-version` for qcamo.

## Installed components

| Component | Default | Source |
|---|---|---|
| MGSHDFix | Yes | [GitHub Releases](https://github.com/ShizCalev/MGSHDFix/releases) |
| MGS3CrouchWalk | Yes | [GitHub Releases](https://github.com/cipherxof/MGS3CrouchWalk/releases) |
| qcamo | No (`--qcamo`) | [GitHub Releases](https://github.com/zexk/mgs3-qcamo/releases) |

MGSHDFix provides resolution, ultrawide, controller, launcher, visual,
performance, and gameplay fixes. MGS3CrouchWalk adds slow and fast crouch
walking, enemy-visibility integration, camo-index adjustments, and localized
animation assets. Optional qcamo adds quick camouflage switching during
gameplay.

Metal Gear and Metal Gear 2: Solid Snake (MSX) are content within the MGS3
Steam installation. MGSHDFix's fixes for those games are therefore included
through this installer rather than a separate installer.

## Loader and launch options

CrouchWalk's bundled `d3d11.dll` is deliberately excluded. MGSHDFix supplies
the only ASI loader and loads `MGS3CrouchWalk.asi` and optional `qcamo.asi`.

```text
WINEDLLOVERRIDES="wininet=n,b;winhttp=n,b" %command%
```

With Steam completely closed, merge these options safely:

```bash
./installers/mgs3/install-mgs3.bash --set-launch-options
```

Do not add a `d3d11` override. Use `--user ACCOUNT_ID` when several Steam
accounts are present.

## Configuration and updates

Leave the game's **Internal Resolution** and **Internal Upscaling** at
**Default / Original**. Configure MGSHDFix using
`plugins/MGSHDFix Config Tool.exe`; Protontricks is required to run it on
Linux. Its generated `MGSHDFix.settings` is always preserved.

Configure CrouchWalk by editing `MGS3CrouchWalk.ini`. A missing INI is created,
an existing INI is preserved byte-for-byte, and changed defaults are written
to `.new`. Use `--reset-ini` to back up and replace it.

Each component has separate state:

```text
<game>/.mgs-installer/mgshdfix/
<game>/.mgs-installer/mgs3crouchwalk/
<game>/.mgs-installer/mgs3qcamo/   (only when `--qcamo` is selected)
```

Overwritten localized animation archives are backed up before replacement.
Legacy MGSHDFix and CrouchWalk manifests and their shared
`.mgshdfix-backup/` remain recognizable.

## Uninstall

```bash
./installers/mgs3/install-mgs3.bash --uninstall
```

CrouchWalk is removed first, restoring animation archives, followed by
MGSHDFix. User-generated MGSHDFix settings are preserved.

## Requirements

- Steam Deck or desktop Linux
- Steam or Flatpak Steam
- Bash 5, Python 3, and `curl`
- Protontricks only when using the MGSHDFix configuration tool

Only published GitHub release assets are installed. The repository's `mods/`
directory is reference material, not an install source.
