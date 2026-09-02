# Metal Gear Solid V: The Phantom Pain Installer

Installs MGSVFix and provides guided Infinite Heaven preparation and recovery
for **Metal Gear Solid V: The Phantom Pain** (Steam AppID `287700`).

## MGSVFix

```bash
./installers/mgsv-tpp/install-mgsv-tpp.bash
```

MGSVFix is downloaded only from
[Codeberg Releases](https://codeberg.org/Lyall/MGSVFix/releases). It can skip
intro screens, unlock framerate and resolutions, correct ultrawide rendering,
and adjust LOD distances.

Existing `MGSVFix.ini` files are preserved byte-for-byte. Changed defaults are
written to `.new`; `--reset-ini` explicitly backs up and replaces the INI.

Required Steam launch options:

```text
WINEDLLOVERRIDES="winmm=n,b" %command%
```

Set them safely with Steam closed using `--set-launch-options`.

## Infinite Heaven

Infinite Heaven cannot be installed headlessly. Its public package is a Nexus
Mods `.mgsv` package that SnakeBite must merge into the game's archives.
SnakeBite is a Windows GUI with no command-line installation mode. The public
source repository is not treated as a distributable release.

The installer automates the safe and scriptable preparation:

```bash
./installers/mgsv-tpp/install-mgsv-tpp.bash --ih
```

This backs up `master/0/00.dat`, `master/0/01.dat`, and detected Steam saves.
The presumed-vanilla archive backup is never overwritten. Use
`--ih-backup-dir PATH` with `--ih` to place a new backup on another drive.

Download Infinite Heaven and IHHook manually from Nexus Mods, then stage both
ZIPs in a Wine-reachable, non-hidden directory:

```bash
./installers/mgsv-tpp/install-mgsv-tpp.bash \
  --ih-zip ~/Downloads/InfiniteHeaven.zip \
  --ih-zip ~/Downloads/IHHook.zip
```

The installer safely extracts the archives under
`InfiniteHeaven-staging/`, reports every `.mgsv` package, and prints the
remaining SnakeBite steps.

Sources:

- [Infinite Heaven](https://www.nexusmods.com/metalgearsolidvtpp/mods/45)
- [IHHook](https://www.nexusmods.com/metalgearsolidvtpp/mods/1226)
- [SnakeBite](https://www.nexusmods.com/metalgearsolidvtpp/mods/106)
- [Steam Deck guide](https://mgsvmoddingwiki.github.io/Steam_Deck/)

Return to the ACC before installing or upgrading Infinite Heaven.

## Infinite Heaven restore

```bash
./installers/mgsv-tpp/install-mgsv-tpp.bash --ih-restore
```

Restore requires the complete default `.mgsv-ih-backup/`. It restores both
vanilla archives, preserves a timestamped copy of `mod/saves`, removes `mod/`,
and removes `Snakebite.xml`. The backup itself is retained.

## State and uninstall

MGSVFix state and backups are stored below
`<game>/.mgs-installer/mgsvfix/`. Legacy MGSVFix manifests and timestamped
backup directories remain recognizable.

`--uninstall` removes only MGSVFix. It never changes Infinite Heaven, game
archives, staged packages, or `mod/`.

## Requirements

- Steam Deck or desktop Linux
- Steam or Flatpak Steam
- Bash, Python 3, and `curl`
- Protontricks and SnakeBite for the manual Infinite Heaven installation

No Nexus content is downloaded automatically.
