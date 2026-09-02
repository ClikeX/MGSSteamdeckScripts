# Per-Game Installer CLI Specification

## 1. Purpose

This document defines the user-facing command-line interface and implementation
requirements for replacing the current mod-centric installers with one installer
per Metal Gear game.

The new workflow MUST:

- give each supported game its own subdirectory and installer;
- give each game a README describing exactly what the installer can install;
- preserve the useful behavior exposed by the existing installers;
- move common Bash functionality into standalone scripts under `util/`;
- download published binaries from GitHub or Forgejo releases whenever they
  exist;
- treat `mods/` submodules as source-code and documentation references only;
- avoid building a mod from source during a normal install;
- support safe updates, dry runs, tracked uninstall, and preservation of user
  configuration.

The primary target is Steam Deck and desktop Linux using Steam or Flatpak Steam.

## 2. Proposed Repository Layout

```text
installers/
  mgs1/
    install-mgs1.bash
    README.md
  mgs2/
    install-mgs2.bash
    README.md
  mgs3/
    install-mgs3.bash
    README.md
  mgs4/
    install-mgs4.bash
    README.md
  mgspw/
    install-mgspw.bash
    README.md
  mgsv-tpp/
    install-mgsv-tpp.bash
    README.md
  mgsv-gz/
    install-mgsv-gz.bash
    README.md
  mc-vol1-bonus/
    install-mc-vol1-bonus.bash
    README.md
  mc-vol2-bonus/
    install-mc-vol2-bonus.bash
    README.md
util/
  cli.bash
  output.bash
  dependencies.bash
  steam-libraries.bash
  steam-path-from-appid.bash
  steam_launch_options.py
  release_github.py
  release_forgejo.py
  archive.py
  payload.bash
  install-state.bash
  installer-core.bash
  protontricks.bash
  release_assets.py
mods/
  ...
```

Installer scripts MUST resolve the repository root relative to their own file
location, source Bash utilities from `util/`, and invoke Python utilities
through their documented command-line interfaces. They MUST work regardless of
the caller's current working directory.

### 2.1 Language boundary

Bash and Python MUST NOT be mixed within one script.

- A Bash script MUST NOT contain embedded Python, Python heredocs,
  `python3 -c`, `python3 -`, or Python modules executed with `python3 -m`.
- If implementing a script correctly requires Python, that script MUST be
  written entirely in Python and stored as a `.py` executable.
- JSON parsing, safe ZIP inspection/extraction, structured VDF editing, and
  similar logic that relies on Python MUST live in standalone Python programs.
- A Bash installer MAY invoke a named standalone Python utility as an external
  command. The Python implementation and its error handling MUST remain wholly
  inside that `.py` file; the Bash caller may only pass arguments, consume
  documented output, and propagate status.
- Python utilities SHOULD use the standard library unless an external
  dependency is explicitly justified and documented.
- A Python utility MUST NOT be hidden inside a Bash wrapper solely to preserve
  a `.bash` filename.

`mods/` MUST NOT be read to obtain an install payload. It MAY be consulted by
maintainers when updating asset rules, default settings, compatibility rules, or
game-specific documentation.

## 3. Installer Catalog

| Installer | Steam AppID | Default components | Optional components |
|---|---:|---|---|
| `mgs1/install-mgs1.bash` | 2131630 | MGSM2Fix | None initially |
| `mgs2/install-mgs2.bash` | 2131640 | MGSHDFix | None initially |
| `mgs3/install-mgs3.bash` | 2131650 | MGSHDFix and MGS3CrouchWalk | `--no-crouchwalk` |
| `mgs4/install-mgs4.bash` | 2492670 | MGSPatriotFix | MGSM2Fix for the MGS1 flashback; MGS4 Mod Loader |
| `mgspw/install-mgspw.bash` | 2492660 | MGSPatriotFix | None initially |
| `mgsv-tpp/install-mgsv-tpp.bash` | 287700 | MGSVFix | Infinite Heaven preparation, staging, reporting, and restore helpers |
| `mgsv-gz/install-mgsv-gz.bash` | 311340 | MGSVFix | None initially |
| `mc-vol1-bonus/install-mc-vol1-bonus.bash` | 2306740 | MGSM2Fix | None initially |
| `mc-vol2-bonus/install-mc-vol2-bonus.bash` | 3036720 | MGSM2Fix | None initially |

MG1 and MG2 MSX are installed as content within the MGS3 Steam installation.
They MUST be documented as part of the MGS3 installer rather than represented
as fake standalone Steam installs.

The MGS4 installer is the single user-facing entry point for all existing MGS4
features. It MUST install MGSPatriotFix by default and expose the MGS1 flashback
fix and MGS4 Mod Loader as named optional components.

## 4. Release Sources

Installers MUST prefer published release assets over checked-out source.

| Component | Release service | Repository |
|---|---|---|
| MGSM2Fix | GitHub Releases | `nuggslet/MGSM2Fix` |
| MGSHDFix | GitHub Releases | `ShizCalev/MGSHDFix` |
| MGS3CrouchWalk | GitHub Releases | `cipherxof/MGS3CrouchWalk` |
| MGSPatriotFix | GitHub Releases | `ShizCalev/MGSPatriotFix` |
| MGSVFix | Codeberg Forgejo Releases | `Lyall/MGSVFix` |
| MGS4 Mod Loader | GitHub Releases, when available | `cipherxof/MGS4-ModLoader` |

Release behavior MUST meet these requirements:

1. The latest stable release is selected by default.
2. Source-code archives generated by the hosting service MUST be ignored.
3. Preview, nightly, prerelease, or draft builds MUST NOT be selected unless the
   user explicitly requests them.
4. Game-specific releases MUST select the correct asset by an explicit,
   case-insensitive asset-name rule:
   - MGSM2Fix: ZIP name containing `MGSM2Fix`.
   - MGSHDFix: ZIP name containing `MGSHDFix`.
   - MGS3CrouchWalk: ZIP name containing `MGS3CrouchWalk` or
     `MGS3_CrouchWalk`.
   - MGS4 PatriotFix: asset containing `MGS4`, excluding Peace Walker names.
   - Peace Walker PatriotFix: asset containing `PW`, `PeaceWalker`, or
     `Peace_Walker`, excluding `MGS4`.
   - MGSVFix: ZIP name beginning with `MGSVFix`.
   - MGS4 Mod Loader: a file named `MGS4ModLoader.asi`, or a ZIP containing
     that file.
5. A release with exactly one eligible ZIP MAY use that ZIP as a fallback.
6. An ambiguous release MUST fail with a useful message rather than install the
   first arbitrary asset.
7. GitHub API rate limiting SHOULD fall back to the public releases page only
   when all of the following are true:
   - `/releases/latest` redirects to a tag in the requested repository;
   - the expanded-assets page belongs to that same repository and tag;
   - the asset URL is an HTTPS `github.com/<owner>/<repo>/releases/download/`
     URL;
   - the asset satisfies the same extension, match, and rejection rules used
     for API results.
8. Forgejo releases MUST use the Forgejo JSON API.
9. `--zip PATH` MUST permit an offline or manually downloaded archive.
10. `--version TAG` SHOULD select a specific published tag when supported by
    the host API.
11. Downloaded files MUST be checked for expected archive type and payload
    markers before installation.
12. If a component has no published binary release, the installer MUST explain
    that fact and accept a local binary or archive. It MUST NOT silently clone
    and compile the project.

## 5. Common CLI

Every per-game installer MUST implement the following interface:

```text
install-<game>.bash [OPTIONS]

  -h, --help                  Show game-specific help and exit
  -l, --list                  Show the detected target and component state
  -n, --dry-run               Print actions without changing files
      --uninstall             Remove files tracked by this installer
  -y, --yes                   Accept safe overwrite or validation prompts
  -p, --path PATH             Use an explicit game directory
      --zip PATH              Use a local archive for the primary component
  -v, --version TAG           Install a specific primary-component release
      --reset-ini             Replace existing INIs with stock defaults
      --set-launch-options    Merge required DLL overrides into Steam config
      --user ACCOUNT_ID       Select a Steam userdata account
```

Rules:

- Per-game installers MUST NOT expose `--game`; the selected script defines the
  game.
- Long options MUST support both `--option VALUE` and `--option=VALUE` where a
  value is required.
- Unknown options, missing values, invalid combinations, and invalid paths MUST
  fail before modifying the game.
- `--dry-run` MUST apply to install, uninstall, settings, launch-option, backup,
  restore, and staging actions.
- `--list` MUST perform no writes and no release download.
- `--list`, `--uninstall`, `--set-launch-options`, `--write-settings`,
  `--ih`, and `--ih-restore` are exclusive operation modes. They perform their
  named operation and exit; they do not also install or update release
  payloads. Users run the installer again without an operation-mode flag to
  install or update components.
- Supplying more than one exclusive operation mode MUST fail before any write.
- `--path`, `--dry-run`, and `--yes` MAY be combined with any applicable
  operation mode.
- `--user` is valid only with `--set-launch-options`.
- Install/update selection flags, including `--zip`, `--version`,
  `--reset-ini`, `--no-crouchwalk`, `--crouchwalk-zip`,
  `--mgs1-flashback`, `--mgs1-flashback-zip`, `--modloader`, and
  `--modloader-file`, MUST be rejected when an exclusive operation mode is
  selected.
- Infinite Heaven preparation is one maintenance mode: `--ih` MAY be combined
  with repeated `--ih-zip` and with `--ih-backup-dir`. Supplying `--ih-zip`
  without `--ih` performs staging and reporting only. `--ih-restore` MUST be
  rejected when combined with `--ih`, `--ih-zip`, or `--ih-backup-dir`.
- Flags not applicable to the selected game or operation MUST fail rather than
  being silently ignored.
- `--path` MUST take precedence over Steam auto-detection.
- If `--path` is used, the installer MUST validate game-specific marker files
  before writing unless `--yes` is supplied.
- Output MUST be usable without color when stdout is not a terminal.
- Errors MUST go to stderr and return a non-zero exit status.
- Temporary directories MUST be removed on normal exit and handled errors.

## 6. Shared User-Facing Behavior

### 6.1 Game detection

Installers MUST:

- support native/package Steam locations:
  - `~/.steam/steam`
  - `~/.steam/root`
  - `~/.local/share/Steam`
- support Flatpak Steam at
  `~/.var/app/com.valvesoftware.Steam/data/Steam`;
- read every library declared in `libraryfolders.vdf`;
- support internal storage, microSD cards, and external Steam libraries;
- prefer AppID manifest lookup through `steam-path-from-appid.bash`;
- use game-specific executable or directory markers only when AppID lookup is
  insufficient, such as the MGS1 flashback nested inside the MGS4 directory;
- canonicalize detected paths and avoid duplicate targets;
- print every searched Steam library when detection fails.

`util/steam-path-from-appid.bash` remains the canonical AppID-to-path command.
Its current contract MUST be preserved:

```text
steam-path-from-appid.bash <appid>

0   game found and absolute path printed
1   Steam or manifest processing error
3   AppID is not installed or its directory is missing
64  invalid usage or AppID
```

### 6.2 Dependency checks

The base install path MAY require only tools normally available on SteamOS plus:

- Bash;
- `curl`;
- `find`;
- `sed`;
- `python3`;

Python-backed utilities MUST check for `python3` before invocation. Bash-only
operations MUST NOT require Python unless they invoke one of those documented
utilities.

Optional features MUST check their own dependencies only when invoked.
Missing optional dependencies MUST NOT block unrelated installs.

### 6.3 Safe file installation

Every component installed into a game MUST have:

- a component-specific manifest at
  `<target>/.mgs-installer/<component>/files.txt` containing relative installed
  paths;
- a component-specific backup tree at
  `<target>/.mgs-installer/<component>/backup/`;
- a stable component identifier used in status and uninstall output.

For a component installed into a nested target, such as the MGS4 MGS1
flashback, `<target>` means the directory that receives that component's files.

Installation MUST:

1. enumerate the archive payload before writing;
2. reject an empty archive;
3. reject unsafe archive entries, including absolute paths and `..` traversal;
4. optionally exclude known unwanted files such as release logs or a duplicate
   ASI loader;
5. validate expected `.asi`, `.dll`, executable, or other component markers;
6. back up a pre-existing file only when it is not already owned by the same
   installer;
7. back up an original file only once;
8. create parent directories as needed;
9. write the new manifest only after a successful install;
10. preserve unrelated files and directories.

An update MUST distinguish original game files from files tracked by an older
installer run. It MUST NOT back up the old mod payload as if it were original
game content.

### 6.4 Configuration preservation

Editable user configuration MUST be preserved by default:

- `MGSM2Fix.ini`;
- `MGSHDFix.settings`;
- `MGS3CrouchWalk.ini`;
- `MGSVFix.ini`;
- `MGS4ModLoader.ini`;
- any future component file explicitly marked as user-editable.

All release-provided or installer-generated INI files MUST use one consistent
flag: `--reset-ini`. `--replace-ini` MUST NOT be implemented.

INI behavior MUST be:

1. If the canonical INI does not exist, the installer MUST create it from the
   selected release or from the component's maintained default template.
2. If the canonical INI already exists, install and update operations MUST
   preserve it byte-for-byte by default.
3. When an updated release contains different defaults, the installer SHOULD
   write them beside the preserved file as `<name>.new`.
4. With `--reset-ini`, the installer MUST back up the existing canonical INI
   and replace it with the selected release's stock defaults.
5. `--reset-ini` applies to every selected component that provides an INI. For
   example, an MGS4 install selecting both the MGS1 flashback and MGS4 Mod
   Loader resets both `MGSM2Fix.ini` and `MGS4ModLoader.ini`.
6. If none of the selected components provides an INI, `--reset-ini` MUST fail
   before modifying the game rather than silently doing nothing.

MGS4 and Peace Walker retain `--write-settings`, which is an exclusive
maintenance operation that generates a complete `MGSPatriotFix.settings`
independently of release installation. It is not an INI reset operation.

`MGSHDFix.settings` is generated outside release installation and MUST never be
overwritten by an update. Users can regenerate it with the MGSHDFix config tool
or remove it manually after backing it up. MGS3CrouchWalk's release-provided
`MGS3CrouchWalk.ini` follows the common `--reset-ini` rules.

### 6.5 Stale-file cleanup

Each component MAY declare files shipped by older versions. During update:

- a stale file MUST be removed only when it is absent from the new payload;
- installer-owned stale files MAY be removed directly;
- an untracked stale file MUST be backed up before removal;
- dry-run output MUST identify stale-file actions.

Automatic stale-file cleanup MUST run only when a current or recognized legacy
manifest proves that the component was previously managed by these installers.
On a first run with no component state, a matching legacy path MUST NOT be
removed automatically. The installer MAY warn that it conflicts with the new
payload and offer to back it up and remove it after explicit confirmation or
`--yes`.

Known legacy paths that the new implementation MUST continue to clean up when
they are absent from the selected release:

| Component | Stale paths |
|---|---|
| MGSHDFix | root-level `d3d11.dll`, root-level `MGSHDFix.asi`, root-level `MGSHDFix Config Tool.exe` |
| MGSM2Fix | `MGSM2Fix.asi`, `d3d11-x64.SHA512`, `dinput8-Win32.SHA512` |
| MGSVFix | `winmm.dll`, `dinput8.dll`, `MGSVFix.asi` |

### 6.6 Uninstall

`--uninstall` MUST:

- remove only paths recorded in component manifests;
- remove generated `.new` configuration files owned by the installer;
- prune only installer-created directories that are empty;
- restore backed-up originals;
- preserve user mod directories and unrelated files;
- report when nothing is tracked;
- remind the user to remove no-longer-needed Steam launch options.

For multi-component games, uninstall SHOULD remove all components managed by
that game's installer. Component-selective uninstall MAY be added later but is
not required for the first implementation.

The first new installer run MUST recognize the legacy manifest and backup names
created by the old scripts. It MUST either migrate them into
`.mgs-installer/<component>/` without losing ownership information or continue
to honor them until the component is cleanly uninstalled. An update MUST NOT
orphan files installed by an old script.

Legacy state is defined as follows:

| Component/workflow | Legacy manifest | Legacy backup |
|---|---|---|
| MGSHDFix | `<target>/.mgshdfix-files.txt` | `<target>/.mgshdfix-backup/` |
| MGS3CrouchWalk | `<target>/.mgs3crouchwalk-files.txt` | shared `<target>/.mgshdfix-backup/` |
| MGSM2Fix | `<target>/.mgsm2fix-files.txt` | `<target>/.mgsm2fix-backup/` |
| MGSPatriotFix | `<target>/.mgspatriotfix-files.txt` | `<target>/.mgspatriotfix-backup/` |
| MGS4 Mod Loader | MGS4 root `.mgs4modloader-files.txt` | no dedicated backup |
| MGSVFix | `<target>/.mgsvfix-manifest.txt` | timestamped `<target>/.mgsvfix-backup-*` directories |
| Infinite Heaven | no install manifest | `<target>/.mgsv-ih-backup/` or `<configured-parent>/mgsv-ih-backup/` |

Legacy shared backups MUST be split or referenced carefully so uninstalling one
component does not consume originals still needed by another component.

### 6.7 Steam launch options

Required launch options are:

| Game/component | Required value |
|---|---|
| MGS1 and Master Collection bonus titles | `WINEDLLOVERRIDES="dinput8=n,b;d3d11=n,b" %command%` |
| MGS2 and MGS3 | `WINEDLLOVERRIDES="wininet,winhttp=n,b" %command%` |
| MGS4 MGSPatriotFix | `WINEDLLOVERRIDES="wininet,winhttp=n,b" %command%` |
| MGS4 with MGSM2Fix flashback support | merge `dinput8=n,b;d3d11=n,b` with the MGS4 overrides |
| Peace Walker | `WINEDLLOVERRIDES="wininet,winhttp=n,b" %command%` |
| MGSV TPP and Ground Zeroes | `WINEDLLOVERRIDES="winmm=n,b" %command%` |

`--set-launch-options` MUST:

- require Steam to be fully closed unless `--yes` is supplied;
- select the requested Steam account or the most recently used account;
- fail clearly when multiple accounts are ambiguous;
- back up `localconfig.vdf` before writing;
- preserve unrelated launch arguments;
- merge DLL override names instead of replacing another mod's overrides;
- preserve the existing DLL order value unless this installer explicitly owns
  that DLL entry;
- make no change when the required options are already present.

The operation MUST derive required overrides from the game's default component
plus current and legacy manifests for installed optional components. For
example, MGS4 MUST add the MGSM2Fix `dinput8` and `d3d11` overrides whenever
flashback MGSM2Fix state is present, without requiring the user to repeat
`--mgs1-flashback`. Existing unrelated or manually configured overrides MUST
still be preserved.

The shared VDF editor MUST live outside the game installers. A single tested
standalone Python implementation MUST replace the duplicated embedded Python
editors currently in the MGSM2Fix and MGSPatriotFix installers.

## 7. Game-Specific Requirements

### 7.1 Metal Gear Solid

`install-mgs1.bash` MUST install MGSM2Fix into the directory containing
`METAL GEAR SOLID.exe`.

It MUST preserve:

- latest stable GitHub release download;
- local ZIP install;
- stale-file cleanup;
- `MGSM2Fix.ini` preservation and `MGSM2Fix.ini.new`;
- `--reset-ini`;
- launch-option merge support;
- backup, update, dry-run, list, and uninstall behavior.

The README MUST mention widescreen, borderless/windowed mode, deadzone removal,
launcher/logo skipping, Ketchup PPF3 mod support, patch controls, and debug
features without promising that this installer configures those features.

### 7.2 Metal Gear Solid 2

`install-mgs2.bash` MUST install MGSHDFix into the MGS2 game root.

It MUST exclude release `logs/` content and manage known stale MGSHDFix files.
After installation it MUST print:

- the required DLL overrides;
- the instruction to leave the game's internal resolution/upscaling at
  Default/Original;
- the discovered MGSHDFix configuration-tool path;
- the Protontricks requirement for the configuration tool.

### 7.3 Metal Gear Solid 3

`install-mgs3.bash` MUST install MGSHDFix and MGS3CrouchWalk by default.

MGSHDFix is the primary component. Therefore the common `--zip` and `--version`
options apply to MGSHDFix.

It MUST:

- expose `--no-crouchwalk`;
- support the common `--reset-ini` behavior for `MGS3CrouchWalk.ini`;
- support `--crouchwalk-zip PATH` and SHOULD support
  `--crouchwalk-version TAG`;
- exclude CrouchWalk's `d3d11.dll` so MGSHDFix's ASI loader remains the single
  loader;
- install CrouchWalk's `.asi`, `.ini`, and animation assets;
- track MGSHDFix and CrouchWalk in separate manifests;
- back up overwritten localized animation archives;
- explain that CrouchWalk is configured by editing `MGS3CrouchWalk.ini`;
- document that MG1 and MG2 MSX fixes are included through this MGS3 install.

### 7.4 Metal Gear Solid 4

`install-mgs4.bash` MUST install the MGS4 release asset of MGSPatriotFix by
default.

MGSPatriotFix is the primary component. Therefore the common `--zip` and
`--version` options apply to MGSPatriotFix.

It MUST preserve:

- `--write-settings`;
- Protontricks/config-tool guidance;
- launch-option editing;
- safe update, backup, and uninstall.

It MUST expose these optional features:

```text
      --mgs1-flashback              Install MGSM2Fix into the nested MGS1 directory
      --mgs1-flashback-zip PATH     Use a local MGSM2Fix archive
      --modloader                   Install MGS4 Mod Loader from a release
      --modloader-file PATH         Use a local .asi file or archive
```

The installer MUST locate the flashback executable `mgs1.exe` and install
MGSM2Fix beside it. When enabled, launch options MUST merge the MGSM2Fix
`dinput8` and `d3d11` overrides with the main MGS4 overrides.

The mod loader MUST:

- be installed only for MGS4;
- be placed where its published release documents require;
- preserve an existing `MGS4ModLoader.ini`;
- create the required `mods/` directory;
- never remove the user's `mods/` directory during uninstall;
- require a published release or `--modloader-file`;
- not compile from the `mods/MGS4-ModLoader` source tree.

### 7.5 Metal Gear Solid: Peace Walker

`install-mgspw.bash` MUST select the Peace Walker MGSPatriotFix release asset.
It MUST expose the same core MGSPatriotFix install, settings, config-tool,
launch-option, backup, update, and uninstall behavior as MGS4, excluding all
MGS4-only components.

### 7.6 Metal Gear Solid V: The Phantom Pain

`install-mgsv-tpp.bash` MUST install MGSVFix from Codeberg's Forgejo releases.
MGSVFix is the primary component.

It MUST preserve:

- latest release and pinned tag selection;
- local ZIP install;
- `MGSVFix.ini` preservation and `.new` defaults;
- common `--reset-ini` behavior;
- stale-loader cleanup;
- launch-option status and setting;
- backup, update, dry-run, list, and uninstall.

Infinite Heaven remains a guided workflow because its public package is a Nexus
Mods SnakeBite package and no headless release installer exists. The script MUST
preserve these options:

```text
      --ih                         Back up vanilla archives and saves, then report state
      --ih-zip PATH                Stage a downloaded Infinite Heaven or IHHook ZIP
      --ih-backup-dir PATH         Store the vanilla archive backup elsewhere
      --ih-restore                 Restore vanilla archives and preserve IH settings
```

The Infinite Heaven workflow MUST:

- back up `master/0/00.dat` and `master/0/01.dat`;
- refuse to overwrite an existing presumed-vanilla archive backup;
- check free space before copying;
- create timestamped save backups;
- stage user-supplied Nexus ZIPs in a Wine-reachable non-hidden directory;
- identify `.mgsv` packages found in staged archives;
- report SnakeBite, `mod/`, backup, Proton prefix, and Protontricks state;
- preserve `mod/saves` before removing `mod/` during restore;
- explain the remaining manual SnakeBite steps and relevant upstream links;
- never download Nexus content automatically or treat its source repository as
  a distributable release.

### 7.7 Metal Gear Solid V: Ground Zeroes

`install-mgsv-gz.bash` MUST provide the MGSVFix behavior shared with TPP but
MUST NOT expose Infinite Heaven options.

### 7.8 Master Collection Bonus Content

The two bonus installers MUST install MGSM2Fix into the directory containing:

- Vol. 1: `MGS MC1 Bonus Content.exe`;
- Vol. 2: `MGS MC2 Bonus Content.exe`.

They MUST preserve the same MGSM2Fix configuration, launch-option, update,
backup, and uninstall semantics as MGS1.

Their READMEs MUST clearly identify the playable content:

- Vol. 1 Bonus Content: Metal Gear and Snake's Revenge;
- Vol. 2 Bonus Content: Metal Gear Solid: Ghost Babel.

## 8. Game README Requirements

Every game README MUST contain:

1. the exact game and Steam AppID, when known;
2. the installer command;
3. a component table stating what is installed by default and what is optional;
4. upstream project links and release sources;
5. files or directories created by the installer at a high level;
6. required Steam launch options;
7. configuration instructions;
8. update behavior and preservation of edited settings;
9. uninstall instructions and backup location;
10. Steam Deck/Linux prerequisites and manual steps;
11. component-specific compatibility notes;
12. limitations, especially features that still require Nexus Mods,
    Protontricks, SnakeBite, or another GUI.

READMEs MUST describe installer behavior, not duplicate exhaustive upstream mod
feature lists. They SHOULD link to upstream documentation for frequently
changing feature details.

## 9. Shared Utility Contracts

### `util/cli.bash`

- parse and validate common flags;
- provide helpers for valued long options;
- reject incompatible operation modes;
- leave game-specific option handling to the installer.

### `util/output.bash`

- provide `info`, `step`, `warn`, `die`, and optional `dim`;
- enable color only on a terminal;
- keep errors on stderr.

### `util/dependencies.bash`

- provide required-command checks;
- check for `python3` before a Python utility is invoked;
- allow optional features to declare dependencies lazily.

### `util/steam-libraries.bash`

- enumerate Steam roots, `steamapps` directories, and library paths;
- canonicalize and deduplicate paths;
- locate manifests and Steam userdata profiles.

### `util/steam-path-from-appid.bash`

- retain its existing standalone CLI;
- also be sourceable without executing its CLI entry point;
- resolve an AppID through all known Steam libraries.

### `util/steam_launch_options.py`

- read, merge, and write `LaunchOptions` in `localconfig.vdf`;
- merge `WINEDLLOVERRIDES` entries without discarding unrelated options;
- make byte-preserving or equivalently safe edits;
- back up the VDF before replacement;
- support dry-run output.

### `util/release_github.py`

- resolve latest stable or requested tags;
- reject source archives and unintended prereleases;
- apply caller-provided asset matching and rejection rules;
- provide a safe HTML fallback for API rate limits;
- return the release tag, asset name, and download URL.

### `util/release_forgejo.py`

- resolve latest stable or requested tags with the Forgejo API;
- apply caller-provided asset selection rules;
- return the release tag, asset name, and download URL.

### `util/release_assets.py`

- provide shared JSON release-asset filtering for GitHub and Forgejo;
- reject drafts, unintended prereleases, source archives, invalid URLs, and
  ambiguous matches;
- apply caller-provided extension, match, rejection, and release URL rules.

### `util/archive.py`

- validate ZIP signatures;
- reject path traversal;
- reject unsafe links and filenames before extraction;
- extract with Python's standard-library `zipfile`;
- descend through a single wrapper directory;
- enumerate relative payload paths.

### `util/payload.bash`

- filter payload paths;
- validate expected markers;
- install files with original-file backup;
- preserve selected editable files;
- clean declared stale files.

### `util/install-state.bash`

- read and write component manifests;
- determine whether a path is installer-owned;
- remove tracked files;
- restore backups;
- prune only safe empty directories.

### `util/installer-core.bash`

- orchestrate common operation dispatch and component sequencing;
- locate and invoke standalone Python utilities through documented CLIs;
- manage temporary workspaces and cleanup;
- keep Python implementation details out of Bash;
- report partial multi-component completion without hiding failures.

### `util/protontricks.bash`

- detect native and Flatpak Protontricks;
- print consistent configuration-tool guidance;
- locate Proton prefixes when needed.

Bash utilities MUST return status rather than exiting where practical. Only the
top-level installer and `die` helper SHOULD terminate the Bash process. Python
utilities MUST return documented process exit codes and write errors to stderr.

## 10. Workflow

Each installer MUST follow the same high-level sequence:

1. Resolve its own directory, source shared Bash utilities, and locate required
   standalone Python utilities.
2. Parse all arguments and validate incompatible modes.
3. Check only the dependencies needed for the selected operation.
4. Resolve the game directory from `--path` or Steam AppID.
5. Validate game-specific marker files and write permission.
6. For `--list`, report the target and installed component state, then exit.
7. For `--set-launch-options`, safely merge options, then exit.
8. For a game-specific maintenance workflow such as Infinite Heaven restore or
   PatriotFix settings generation, perform only that workflow, then exit.
9. For uninstall, remove tracked components in dependency-safe order and
   restore backups.
10. Resolve all requested release assets before modifying the game.
11. Download to a temporary directory, validate, extract, and enumerate all
    payloads.
12. Compare each new payload with its current and legacy manifests, then plan
    stale-file cleanup without deleting any path shipped by the new payload.
13. Print a component and target summary.
14. Remove or back up planned stale files immediately before installing the
    corresponding new component.
15. Install primary components before dependent plugins or mod loaders.
16. Write component manifests only after their payload succeeds.
17. Print concise remaining manual steps, configuration paths, backup paths,
    and the uninstall command.

Multi-component installation SHOULD be transactional at the component level.
If an optional component fails, the installer MUST clearly report which earlier
components were installed and how to uninstall them. A later phase MAY add a
full rollback transaction.

## 11. Migration Plan

### Phase 1: Shared foundation

1. Refactor `steam-path-from-appid.bash` so it remains executable and can also
   be sourced.
2. Extract output, Steam-library, archive, release, payload, manifest, and
   launch-option logic from the existing scripts.
3. Add focused Bash tests for Bash utilities and Python tests for Python
   utilities, covering path resolution, asset selection, manifest ownership,
   archive traversal rejection, configuration preservation, and VDF
   launch-option merging.

### Phase 2: Straightforward per-game installers

Implement MGS1, MGS2, Peace Walker, Ground Zeroes, and both bonus installers
first. These establish the common interfaces with one primary component each.

### Phase 3: Multi-component installers

1. Implement MGS3 with MGSHDFix plus MGS3CrouchWalk.
2. Implement MGS4 with MGSPatriotFix, optional flashback MGSM2Fix, and optional
   release-based MGS4 Mod Loader.
3. Verify that combined MGS4 launch options preserve every required override.

### Phase 4: Guided external workflow

Implement TPP's Infinite Heaven backup, staging, report, and restore commands on
top of the new shared utilities. Keep Nexus downloads and SnakeBite installation
manual.

### Phase 5: Documentation and cutover

1. Write each game README from the requirements above.
2. Update the root README with the per-game command matrix.
3. Mark the four old mod-centric scripts as deprecated for one release.
4. Remove the old scripts after feature-parity validation.
5. Keep compatibility wrappers only if external links or users depend on the
   old names; wrappers MUST print the replacement command.

## 12. Acceptance Criteria

The redesign is complete when:

- every game in the installer catalog has its own subdirectory, script, and
  README;
- no per-game script contains a `--game` selector;
- common release, Steam, archive, backup, manifest, and launch-option logic is
  not duplicated across installers;
- no normal install copies binaries from `mods/` or compiles a mod from source;
- every available GitHub or Forgejo binary is obtained from a release asset;
- all existing dry-run, local archive, update, configuration preservation,
  stale cleanup, backup, uninstall, and Steam-library behaviors are retained;
- every absent release-provided INI is created, every existing INI is preserved
  by default, and `--reset-ini` is the only flag that permits replacement;
- MGS3 correctly composes MGSHDFix and CrouchWalk without two ASI loaders;
- MGS4 correctly composes its main fix, optional flashback fix, and optional mod
  loader without clobbering launch options;
- TPP retains the complete Infinite Heaven preparation and recovery workflow;
- uninstall never removes user mod directories or unrelated game files;
- shell syntax checks pass for Bash files, Python compilation/tests pass for
  Python files, and all focused utility tests pass on SteamOS-compatible tools.
