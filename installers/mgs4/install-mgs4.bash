#!/usr/bin/env bash

set -euo pipefail

INSTALLER_DIR=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
		pwd -P
)
# shellcheck source=util/installer-core.bash
source "$INSTALLER_DIR/../../util/installer-core.bash"
mgs_installer_init "${BASH_SOURCE[0]}"
# shellcheck source=util/mgspatriotfix-installer.bash
source "$MGS_UTIL_DIR/mgspatriotfix-installer.bash"
# shellcheck source=util/mgsm2fix-installer.bash
source "$MGS_UTIL_DIR/mgsm2fix-installer.bash"

readonly APPID=2492670
readonly GAME_MARKER="MGS4/mgs4.exe"
readonly MGS_GAME_NAME="Metal Gear Solid 4"
readonly MGS_GAME_APPID=$APPID
readonly MGS_PATRIOTFIX_GAME_KEY=mgs4
readonly MGS_PATRIOTFIX_ASSET_MATCH=MGS4
readonly MGS_PATRIOTFIX_ASSET_REJECT='PW|Peace.?Walker'

MGS4_WRITE_SETTINGS=0
MGS4_WANT_FLASHBACK=0
MGS4_FLASHBACK_ZIP=
MGS4_WANT_MODLOADER=0
MGS4_MODLOADER_FILE=

usage() {
	cat <<'EOF'
Install MGSPatriotFix and optional MGS4 components.

Usage: install-mgs4.bash [OPTIONS]

  -h, --help                  Show this help
  -l, --list                  Show the game and component install state
  -n, --dry-run               Print actions without changing files
      --uninstall             Remove tracked components and restore backups
      --write-settings        Write complete default PatriotFix settings
  -y, --yes                   Overwrite settings or accept other warnings
  -p, --path PATH             Use an explicit MGS4 game root
      --zip PATH              Use a local MGS4 MGSPatriotFix ZIP
  -v, --version TAG           Install a specific PatriotFix GitHub release
      --mgs1-flashback        Install MGSM2Fix beside the nested mgs1.exe
      --mgs1-flashback-zip P  Use a local MGSM2Fix ZIP
      --modloader             Install MGS4 Mod Loader from a stable release
      --modloader-file PATH   Use a local Mod Loader .asi or ZIP
      --reset-ini             Reset selected optional-component INIs
      --set-launch-options    Merge overrides derived from installed state
      --user ACCOUNT_ID       Select a Steam userdata account
EOF
}

mgs4_parse_option() {
	local value

	case "$1" in
		--write-settings)
			MGS4_WRITE_SETTINGS=1
			mgs_cli_set_exclusive write-settings
			MGS_CLI_CONSUMED=1
			;;
		--mgs1-flashback)
			MGS4_WANT_FLASHBACK=1
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=1
			;;
		--mgs1-flashback-zip)
			value=$(mgs_cli_value "$1" "${2-}") || return
			MGS4_WANT_FLASHBACK=1
			MGS4_FLASHBACK_ZIP=$value
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=2
			;;
		--mgs1-flashback-zip=*)
			value=$(mgs_cli_value --mgs1-flashback-zip "${1#*=}") || return
			MGS4_WANT_FLASHBACK=1
			MGS4_FLASHBACK_ZIP=$value
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=1
			;;
		--modloader)
			MGS4_WANT_MODLOADER=1
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=1
			;;
		--modloader-file)
			value=$(mgs_cli_value "$1" "${2-}") || return
			MGS4_WANT_MODLOADER=1
			MGS4_MODLOADER_FILE=$value
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=2
			;;
		--modloader-file=*)
			value=$(mgs_cli_value --modloader-file "${1#*=}") || return
			MGS4_WANT_MODLOADER=1
			MGS4_MODLOADER_FILE=$value
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=1
			;;
		*) return 1 ;;
	esac
}

mgs4_find_flashback() {
	local target=$1
	local match

	match=$(find "$target" -maxdepth 4 -type f -iname mgs1.exe -print -quit)
	if [[ -n $match ]]; then
		dirname -- "$match"
		return 0
	fi
	match=$(find "$target" -maxdepth 5 -type f \
		\( -path '*/.mgs-installer/mgsm2fix/files.txt' \
		-o -name .mgsm2fix-files.txt \) -print -quit)
	[[ -n $match ]] || return 1
	if [[ $match == */.mgs-installer/mgsm2fix/files.txt ]]; then
		dirname -- "$(dirname -- "$(dirname -- "$match")")"
	else
		dirname -- "$match"
	fi
}

mgs4_game_subdir() {
	local target=$1
	local match

	match=$(find "$target" -maxdepth 3 -type f -iname mgs4.exe -print -quit)
	[[ -n $match ]] || return 1
	dirname -- "$match"
}

mgs4_write_settings() {
	local target=$1
	local -a command=(
		"$MGS_UTIL_DIR/patriot_settings.py"
		"$target/MGSPatriotFix.settings"
		--game mgs4
	)

	mgs_require_command python3 || return
	(( MGS_CLI_ASSUME_YES )) && command+=(--force)
	(( MGS_CLI_DRY_RUN )) && command+=(--dry-run)
	"${command[@]}"
}

mgs4_prepare_modloader() {
	local target=$1
	local workspace=$2
	local game_dir game_relative input extracted resolved
	local release_tag asset_name asset_url asi ini
	local -a matches=()

	game_dir=$(mgs4_game_subdir "$target") ||
		mgs_die "could not locate the directory containing mgs4.exe"
	game_relative=${game_dir#"$target"/}

	if [[ -n $MGS4_MODLOADER_FILE ]]; then
		input=$(mgs_installer_absolute_file "$MGS4_MODLOADER_FILE") || return
	else
		if ! resolved=$(
			mgs_installer_github_release cipherxof/MGS4-ModLoader \
				MGS4-ModLoader "" '\.(zip|asi)$' "" 2>/dev/null
		); then
			mgs_die "no stable MGS4 Mod Loader release asset is available.
Download a trusted release asset yourself and use --modloader-file PATH."
		fi
		IFS=$'\t' read -r release_tag asset_name asset_url <<< "$resolved"
		[[ -n ${asset_url:-} ]] ||
			mgs_die "the stable MGS4 Mod Loader release has no binary asset"
		mgs_info "Mod Loader release: $release_tag"
		mgs_info "Mod Loader asset: $asset_name"
		if [[ ${asset_name,,} == *.zip ]]; then
			input=$workspace/modloader-download.zip
		else
			input=$workspace/MGS4ModLoader.asi
		fi
		mgs_installer_download "$asset_url" "$input"
	fi

	mkdir -p "$workspace/modloader-source/$game_relative/scripts"
	if [[ ${input,,} == *.zip ]]; then
		extracted=$(mgs_installer_extract_archive "$input" \
			"$workspace/modloader-extracted") || return
		while IFS= read -r asi; do
			matches+=("$asi")
		done < <(find "$extracted" -type f -iname MGS4ModLoader.asi)
		(( ${#matches[@]} == 1 )) ||
			mgs_die "the Mod Loader archive must contain exactly one MGS4ModLoader.asi"
		asi=${matches[0]}
		ini=$(find "$extracted" -type f -iname MGS4ModLoader.ini -print -quit)
	else
		[[ $(basename -- "$input") == MGS4ModLoader.asi ]] ||
			mgs_die "--modloader-file must be MGS4ModLoader.asi or a ZIP containing it"
		asi=$input
		ini=
	fi

	MGS4_MODLOADER_SOURCE=$workspace/modloader-source
	MGS4_MODLOADER_INI_PATH=$game_relative/scripts/MGS4ModLoader.ini
	cp -f "$asi" "$MGS4_MODLOADER_SOURCE/$game_relative/scripts/MGS4ModLoader.asi"
	if [[ -n $ini ]]; then
		cp -f "$ini" "$MGS4_MODLOADER_SOURCE/$MGS4_MODLOADER_INI_PATH"
	else
		printf '%s\n' \
			'[ModLoader]' \
			'Enabled = true' \
			'ModsDirectory = mods' \
			'LogOverrides = true' \
			'LogAllFileReads = false' \
			'LogSlotResources = false' \
			> "$MGS4_MODLOADER_SOURCE/$MGS4_MODLOADER_INI_PATH"
	fi
	MGS4_MODS_DIR=$game_dir/mods
}

mgs4_install_modloader() {
	local target=$1
	local -a modloader_ini_paths=("$MGS4_MODLOADER_INI_PATH")
	local -a modloader_stale_paths=()

	mgs_payload_install "$target" "$MGS4_MODLOADER_SOURCE" mgs4modloader \
		"$MGS_CLI_RESET_INI" "$MGS_CLI_DRY_RUN" "" \
		'(^|/)MGS4ModLoader\.asi$' modloader_ini_paths \
		modloader_stale_paths
	if (( MGS_CLI_DRY_RUN )); then
		printf 'would create mods directory %s\n' "$MGS4_MODS_DIR"
	else
		mkdir -p "$MGS4_MODS_DIR"
	fi
}

mgs_cli_parse mgs4_parse_option "$@" || exit $?

if (( MGS_CLI_HELP )); then
	usage
	exit 0
fi
if (( MGS_CLI_RESET_INI && ! MGS4_WANT_FLASHBACK && ! MGS4_WANT_MODLOADER )); then
	mgs_cli_error "--reset-ini requires --mgs1-flashback or --modloader"
	exit $?
fi

TARGET=$(mgs_installer_resolve_target "$APPID" "$GAME_MARKER")
FLASHBACK_TARGET=$(mgs4_find_flashback "$TARGET" || true)

if (( MGS_CLI_LIST )); then
	mgs_info "Metal Gear Solid 4: $TARGET"
	for COMPONENT in mgspatriotfix mgs4modloader; do
		if mgs_state_has_state "$TARGET" "$COMPONENT"; then
			mgs_info "$COMPONENT: installed"
		else
			mgs_info "$COMPONENT: not installed by this installer"
		fi
	done
	if [[ -n $FLASHBACK_TARGET ]] &&
		mgs_state_has_state "$FLASHBACK_TARGET" mgsm2fix; then
		mgs_info "MGS1 flashback MGSM2Fix: installed"
	else
		mgs_info "MGS1 flashback MGSM2Fix: not installed by this installer"
	fi
	exit 0
fi

if (( MGS_CLI_SET_LAUNCH_OPTIONS )); then
	OVERRIDES='wininet=n,b;winhttp=n,b'
	if [[ -n $FLASHBACK_TARGET ]] &&
		mgs_state_has_state "$FLASHBACK_TARGET" mgsm2fix; then
		OVERRIDES+=';dinput8=n,b;d3d11=n,b'
	fi
	mgs_installer_set_launch_options "$APPID" "$OVERRIDES"
	exit $?
fi

if (( MGS4_WRITE_SETTINGS )); then
	mgs4_write_settings "$TARGET"
	exit $?
fi

if (( MGS_CLI_UNINSTALL )); then
	UNINSTALLED=0
	if mgs_state_uninstall "$TARGET" mgs4modloader "$MGS_CLI_DRY_RUN"; then
		mgs_info "MGS4 Mod Loader removed; user mods were preserved."
		UNINSTALLED=1
	fi
	if [[ -n $FLASHBACK_TARGET ]] &&
		mgs_state_uninstall "$FLASHBACK_TARGET" mgsm2fix "$MGS_CLI_DRY_RUN"; then
		mgs_info "MGS1 flashback MGSM2Fix removed."
		UNINSTALLED=1
	fi
	if mgs_state_uninstall "$TARGET" mgspatriotfix "$MGS_CLI_DRY_RUN"; then
		mgs_info "MGSPatriotFix removed."
		UNINSTALLED=1
	fi
	(( UNINSTALLED )) || {
		mgs_warn "No tracked MGS4 components were found in $TARGET"
		exit 3
	}
	exit 0
fi

mgs_require_command python3
mgs_require_command curl
mgs_installer_create_workspace mgs4

mgs_patriotfix_acquire "$MGS_WORK_DIR/patriot" "$MGS_CLI_ZIP" \
	"$MGS_CLI_VERSION"

if (( MGS4_WANT_FLASHBACK )); then
	[[ -n $FLASHBACK_TARGET ]] ||
		mgs_die "could not locate the nested mgs1.exe flashback"
	mgs_mgsm2fix_acquire "$MGS_WORK_DIR/flashback" "$MGS4_FLASHBACK_ZIP"
fi

if (( MGS4_WANT_MODLOADER )); then
	mgs4_prepare_modloader "$TARGET" "$MGS_WORK_DIR/modloader"
fi

mgs_step "Installing MGSPatriotFix into $TARGET"
mgs_patriotfix_install "$TARGET" "$MGS_CLI_DRY_RUN"

if (( MGS4_WANT_FLASHBACK )); then
	mgs_step "Installing MGSM2Fix into $FLASHBACK_TARGET"
	mgs_mgsm2fix_install "$FLASHBACK_TARGET" "$MGS_CLI_RESET_INI" \
		"$MGS_CLI_DRY_RUN"
fi

if (( MGS4_WANT_MODLOADER )); then
	mgs_step "Installing MGS4 Mod Loader"
	mgs4_install_modloader "$TARGET"
fi

if (( MGS_CLI_DRY_RUN )); then
	mgs_info "Dry run complete; nothing was written."
	exit 0
fi

CONFIG_TOOL_REL=$(
	mgs_patriotfix_config_tool "$MGS_PATRIOTFIX_SOURCE" || true
)

cat <<EOF

Selected MGS4 components are installed.

Base Steam launch options:
  WINEDLLOVERRIDES="wininet=n,b;winhttp=n,b" %command%

Run this after installing optional components so overrides are derived from
persisted component state:
  $0 --path "$TARGET" --set-launch-options

MGSPatriotFix configuration tool:
  ${CONFIG_TOOL_REL:+$TARGET/$CONFIG_TOOL_REL}
  ${CONFIG_TOOL_REL:-MGSPatriotFix configuration tool not found in this release.}

Generate default PatriotFix settings without the GUI:
  $0 --path "$TARGET" --write-settings
EOF

if (( MGS4_WANT_FLASHBACK )); then
	printf '\nMGS1 flashback configuration:\n  %s/MGSM2Fix.ini\n' \
		"$FLASHBACK_TARGET"
fi
if (( MGS4_WANT_MODLOADER )); then
	printf '\nMGS4 mods directory:\n  %s\n' "$MGS4_MODS_DIR"
fi

cat <<EOF

Uninstall all tracked MGS4 components:
  $0 --path "$TARGET" --uninstall
EOF
