#!/usr/bin/env bash

set -euo pipefail

INSTALLER_DIR=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
		pwd -P
)
# shellcheck source=util/installer-core.bash
source "$INSTALLER_DIR/../../util/installer-core.bash"
mgs_installer_init "${BASH_SOURCE[0]}"
# shellcheck source=util/mgshdfix-installer.bash
source "$MGS_UTIL_DIR/mgshdfix-installer.bash"

readonly APPID=2131640
readonly GAME_MARKER="METAL GEAR SOLID2.exe"
readonly OVERRIDES='wininet=n,b;winhttp=n,b'
readonly MGS2_BUGFIX_REPO=ShizCalev/MGS2-Community-Bugfix-Compilation
readonly MGS2_MOD_ORDER_NOTE=.mgs-installer/mgs2communitybugfix/mod-order.txt

MGS2_WANT_COMMUNITY_BUGFIX=1
MGS2_COMMUNITY_BUGFIX_ZIP=
MGS2_COMMUNITY_BUGFIX_VERSION=
MGS2_TEXTURE_PACK=
MGS2_TEXTURE_2X_SELECTED=0
MGS2_TEXTURE_4X_SELECTED=0
MGS2_TEXTURE_2X_ZIP=
MGS2_TEXTURE_2X_VERSION=
MGS2_TEXTURE_4X_ZIP=
MGS2_TEXTURE_4X_VERSION=

usage() {
	cat <<'EOF'
Install or update MGSHDFix and the MGS2 Community Bugfix Compilation for
Metal Gear Solid 2: Master Collection Version.

Usage: install-mgs2.bash [OPTIONS]

  -h, --help                    Show this help
  -l, --list                    Show the detected game and install state
  -n, --dry-run                 Print actions without changing files
      --uninstall               Remove tracked files and restore backups
  -y, --yes                     Accept a missing marker or edit while Steam runs
  -p, --path PATH               Use an explicit game directory
      --zip PATH                Install from a local MGSHDFix ZIP
  -v, --version TAG             Install a specific MGSHDFix GitHub release
      --no-community-bugfix     Install only MGSHDFix
      --community-bugfix-zip P  Use a local Community Bugfix base ZIP
      --community-bugfix-version TAG
                                Install a specific Community Bugfix release
      --textures-2x             Install the optional 2x texture add-on
      --textures-2x-zip PATH    Use a local 2x texture ZIP
      --textures-2x-version TAG Install a specific 2x texture release
      --textures-4x             Install the optional 4x texture add-on
      --textures-4x-zip PATH    Use a local 4x texture ZIP
      --textures-4x-version TAG Install a specific 4x texture release
      --reset-ini               Reset the Community Bugfix INI to release defaults
      --set-launch-options      Merge required DLL overrides into Steam config
      --user ACCOUNT_ID         Select a Steam userdata account
EOF
}

mgs2_parse_option() {
	local value

	case "$1" in
		--no-community-bugfix)
			MGS2_WANT_COMMUNITY_BUGFIX=0
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=1
			;;
		--community-bugfix-zip)
			value=$(mgs_cli_value "$1" "${2-}") || return
			MGS2_WANT_COMMUNITY_BUGFIX=1
			MGS2_COMMUNITY_BUGFIX_ZIP=$value
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=2
			;;
		--community-bugfix-zip=*)
			value=$(mgs_cli_value --community-bugfix-zip "${1#*=}") || return
			MGS2_WANT_COMMUNITY_BUGFIX=1
			MGS2_COMMUNITY_BUGFIX_ZIP=$value
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=1
			;;
		--community-bugfix-version)
			value=$(mgs_cli_value "$1" "${2-}") || return
			MGS2_WANT_COMMUNITY_BUGFIX=1
			MGS2_COMMUNITY_BUGFIX_VERSION=$value
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=2
			;;
		--community-bugfix-version=*)
			value=$(mgs_cli_value --community-bugfix-version "${1#*=}") || return
			MGS2_WANT_COMMUNITY_BUGFIX=1
			MGS2_COMMUNITY_BUGFIX_VERSION=$value
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=1
			;;
		--textures-2x)
			MGS2_TEXTURE_PACK=2x
			MGS2_TEXTURE_2X_SELECTED=1
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=1
			;;
		--textures-2x-zip)
			value=$(mgs_cli_value "$1" "${2-}") || return
			MGS2_TEXTURE_PACK=2x
			MGS2_TEXTURE_2X_SELECTED=1
			MGS2_TEXTURE_2X_ZIP=$value
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=2
			;;
		--textures-2x-zip=*)
			value=$(mgs_cli_value --textures-2x-zip "${1#*=}") || return
			MGS2_TEXTURE_PACK=2x
			MGS2_TEXTURE_2X_SELECTED=1
			MGS2_TEXTURE_2X_ZIP=$value
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=1
			;;
		--textures-2x-version)
			value=$(mgs_cli_value "$1" "${2-}") || return
			MGS2_TEXTURE_PACK=2x
			MGS2_TEXTURE_2X_SELECTED=1
			MGS2_TEXTURE_2X_VERSION=$value
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=2
			;;
		--textures-2x-version=*)
			value=$(mgs_cli_value --textures-2x-version "${1#*=}") || return
			MGS2_TEXTURE_PACK=2x
			MGS2_TEXTURE_2X_SELECTED=1
			MGS2_TEXTURE_2X_VERSION=$value
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=1
			;;
		--textures-4x)
			MGS2_TEXTURE_PACK=4x
			MGS2_TEXTURE_4X_SELECTED=1
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=1
			;;
		--textures-4x-zip)
			value=$(mgs_cli_value "$1" "${2-}") || return
			MGS2_TEXTURE_PACK=4x
			MGS2_TEXTURE_4X_SELECTED=1
			MGS2_TEXTURE_4X_ZIP=$value
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=2
			;;
		--textures-4x-zip=*)
			value=$(mgs_cli_value --textures-4x-zip "${1#*=}") || return
			MGS2_TEXTURE_PACK=4x
			MGS2_TEXTURE_4X_SELECTED=1
			MGS2_TEXTURE_4X_ZIP=$value
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=1
			;;
		--textures-4x-version)
			value=$(mgs_cli_value "$1" "${2-}") || return
			MGS2_TEXTURE_PACK=4x
			MGS2_TEXTURE_4X_SELECTED=1
			MGS2_TEXTURE_4X_VERSION=$value
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=2
			;;
		--textures-4x-version=*)
			value=$(mgs_cli_value --textures-4x-version "${1#*=}") || return
			MGS2_TEXTURE_PACK=4x
			MGS2_TEXTURE_4X_SELECTED=1
			MGS2_TEXTURE_4X_VERSION=$value
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=1
			;;
		*) return 1 ;;
	esac
}

mgs2_texture_component() {
	case "${1-}" in
		2x) printf '%s\n' mgs2communitybugfix2x ;;
		4x) printf '%s\n' mgs2communitybugfix4x ;;
		*) return 1 ;;
	esac
}

mgs2_texture_label() {
	case "${1-}" in
		2x) printf '%s\n' "MGS2 Community Bugfix Compilation 2x texture add-on" ;;
		4x) printf '%s\n' "MGS2 Community Bugfix Compilation 4x texture add-on" ;;
		*) return 1 ;;
	esac
}

mgs2_bugfix_acquire_base() {
	local workspace=$1
	local zip_override=${2-}
	local version=${3-}
	local zip release_tag asset_name asset_url extracted_root stage_root

	mkdir -p "$workspace"
	if [[ -n $zip_override ]]; then
		zip=$(mgs_installer_absolute_file "$zip_override") || return
		mgs_step "Using local MGS2 Community Bugfix base archive $(basename -- "$zip")"
	else
		mgs_step "Resolving MGS2 Community Bugfix base release"
		IFS=$'\t' read -r release_tag asset_name asset_url < <(
			mgs_installer_github_release "$MGS2_BUGFIX_REPO" \
				'Base' '2x|4x|Upscaled' '\.zip$' "$version"
		)
		[[ -n ${asset_url:-} ]] ||
			mgs_die "no MGS2 Community Bugfix base release asset was resolved"
		mgs_info "Release: $release_tag"
		mgs_info "Asset: $asset_name"
		zip=$workspace/mgs2-community-bugfix-base.zip
		mgs_installer_download "$asset_url" "$zip"
	fi

	mgs_step "Validating and extracting MGS2 Community Bugfix base"
	extracted_root=$(
		mgs_installer_extract_archive "$zip" "$workspace/mgs2-community-bugfix-base"
	) || return
	stage_root=$workspace/mgs2-community-bugfix-base-staged
	rm -rf "$stage_root"
	mkdir -p "$stage_root" || return
	cp -R "$extracted_root"/. "$stage_root"/ || return
	mgs2_write_mod_order_note "$stage_root" || return
	MGS2_COMMUNITY_BUGFIX_SOURCE=$stage_root
}

mgs2_bugfix_stage_textures() {
	local extracted_root=$1
	local stage_root=$2
	local source_dir=

	if [[ -d $extracted_root/textures/flatlist/ovr_stm ]]; then
		source_dir=$extracted_root/textures/flatlist/ovr_stm
	elif [[ -d $extracted_root/flatlist/ovr_stm ]]; then
		source_dir=$extracted_root/flatlist/ovr_stm
	elif [[ -d $extracted_root/ovr_stm ]]; then
		source_dir=$extracted_root/ovr_stm
	elif [[ -d $extracted_root/_win ]]; then
		source_dir=$extracted_root
	fi

	[[ -n $source_dir ]] ||
		mgs_die "could not locate Community Bugfix texture payload content"

	rm -rf "$stage_root"
	mkdir -p "$stage_root/textures/flatlist" || return
	cp -R "$source_dir" "$stage_root/textures/flatlist/ovr_stm" || return
}

mgs2_bugfix_acquire_textures() {
	local workspace=$1
	local size=$2
	local zip_override=${3-}
	local version=${4-}
	local zip release_tag asset_name asset_url part_tag part_name part_url part_number
	local concat_zip expected_part extracted_root stage_root
	local -a asset_rows=()

	mkdir -p "$workspace"
	if [[ -n $zip_override ]]; then
		zip=$(mgs_installer_absolute_file "$zip_override") || return
		mgs_step "Using local $(mgs2_texture_label "$size") archive $(basename -- "$zip")"
	else
		case "$size" in
			2x)
				mgs_step "Resolving MGS2 Community Bugfix 2x texture release"
				IFS=$'\t' read -r release_tag asset_name asset_url < <(
					mgs_installer_github_release "$MGS2_BUGFIX_REPO" \
						'2x.*Upscaled' '4x|Base' '\.zip$' "$version"
				)
				[[ -n ${asset_url:-} ]] ||
					mgs_die "no MGS2 Community Bugfix 2x texture release asset was resolved"
				mgs_info "Release: $release_tag"
				mgs_info "Asset: $asset_name"
				zip=$workspace/mgs2-community-bugfix-2x.zip
				mgs_installer_download "$asset_url" "$zip"
				;;
			4x)
				mgs_step "Resolving MGS2 Community Bugfix 4x texture release"
				mapfile -t asset_rows < <(
					mgs_installer_github_release_assets "$MGS2_BUGFIX_REPO" \
						'4x.*Upscaled' '2x|Base' '\.zip\.[0-9]{3}$' "$version"
				)
				(( ${#asset_rows[@]} > 0 )) ||
					mgs_die "no MGS2 Community Bugfix 4x texture release assets were resolved"
				concat_zip=$workspace/mgs2-community-bugfix-4x.zip
				: > "$concat_zip"
				expected_part=1
				for asset_row in "${asset_rows[@]}"; do
					IFS=$'\t' read -r part_tag part_name part_url <<< "$asset_row"
					[[ -n $part_url ]] ||
						mgs_die "a resolved MGS2 Community Bugfix 4x texture part had no download URL"
					[[ $part_name =~ \.zip\.([0-9]{3})$ ]] ||
						mgs_die "unexpected 4x texture part name: $part_name"
					part_number=$((10#${BASH_REMATCH[1]}))
					(( part_number == expected_part )) ||
						mgs_die "4x texture release parts must be contiguous from .001"
					[[ -n ${release_tag:-} && $release_tag != "$part_tag" ]] &&
						mgs_die "resolved 4x texture assets did not share one release tag"
					release_tag=$part_tag
					mgs_info "Asset: $part_name"
					mgs_installer_download "$part_url" "$workspace/$part_name"
					cat "$workspace/$part_name" >> "$concat_zip"
					expected_part=$((expected_part + 1))
				done
				mgs_info "Release: $release_tag"
				zip=$concat_zip
				;;
			*)
				mgs_die "unsupported texture pack selection: $size"
				;;
		esac
	fi

	mgs_step "Validating and extracting $(mgs2_texture_label "$size")"
	extracted_root=$(
		mgs_installer_extract_archive "$zip" "$workspace/mgs2-community-bugfix-$size"
	) || return
	stage_root=$workspace/mgs2-community-bugfix-$size-staged
	mgs2_bugfix_stage_textures "$extracted_root" "$stage_root" || return
	MGS2_TEXTURE_SOURCE=$stage_root
}

mgs2_bugfix_install_base() {
	local target=$1
	local reset_ini=$2
	local dry_run=$3
	local -a bugfix_ini_paths=(plugins/MGS2-Community-Bugfix-Compilation.ini)
	local -a bugfix_stale_paths=()

	mgs_payload_install "$target" "$MGS2_COMMUNITY_BUGFIX_SOURCE" \
		mgs2communitybugfix "$reset_ini" "$dry_run" "" \
		'(^|/)MGS2-Community-Bugfix-Compilation\.asi$' bugfix_ini_paths \
		bugfix_stale_paths
}

mgs2_bugfix_install_textures() {
	local target=$1
	local size=$2
	local dry_run=$3
	local component
	local -a texture_ini_paths=()
	local -a texture_stale_paths=()

	component=$(mgs2_texture_component "$size") || return
	mgs_payload_install "$target" "$MGS2_TEXTURE_SOURCE" "$component" 0 "$dry_run" "" \
		'(^|/)textures/flatlist/ovr_stm/_win/col_orange2\.bmp\.ctxr$' \
		texture_ini_paths texture_stale_paths
}

mgs2_write_mod_order_note() {
	local target=$1

	mkdir -p "$(dirname -- "$target/$MGS2_MOD_ORDER_NOTE")" || return
	cat > "$target/$MGS2_MOD_ORDER_NOTE" <<EOF
Recommended MGS2 mod load order (first loaded to last):
1. MGSHDFix
2. Knight_Killer's MGS2 Better Audio Mod
3. MGS2 Community Bugfix Compilation - Base
4. MGS2 Community Bugfix Compilation - AI Upscaled Texture Add-on (if installed)
5. MGS2 Demastered Texture Pack (if installed)
6. All other mods

The installer always applies the Community Bugfix base before its optional
texture add-on so direct installs follow the required overwrite order.
EOF
}

mgs_cli_parse mgs2_parse_option "$@" || exit $?

if (( MGS_CLI_HELP )); then
	usage
	exit 0
fi
if [[ -n $MGS2_COMMUNITY_BUGFIX_ZIP && -n $MGS2_COMMUNITY_BUGFIX_VERSION ]]; then
	mgs_cli_error "--community-bugfix-zip and --community-bugfix-version cannot be combined"
	exit $?
fi
if (( ! MGS2_WANT_COMMUNITY_BUGFIX )) &&
	[[ -n $MGS2_COMMUNITY_BUGFIX_ZIP || -n $MGS2_COMMUNITY_BUGFIX_VERSION ]]; then
	mgs_cli_error "Community Bugfix source options cannot be used with --no-community-bugfix"
	exit $?
fi
if (( ! MGS2_WANT_COMMUNITY_BUGFIX )) && [[ -n $MGS2_TEXTURE_PACK ]]; then
	mgs_cli_error "texture add-ons require the Community Bugfix base package"
	exit $?
fi
if [[ -n $MGS2_TEXTURE_2X_ZIP && -n $MGS2_TEXTURE_2X_VERSION ]]; then
	mgs_cli_error "--textures-2x-zip and --textures-2x-version cannot be combined"
	exit $?
fi
if [[ -n $MGS2_TEXTURE_4X_ZIP && -n $MGS2_TEXTURE_4X_VERSION ]]; then
	mgs_cli_error "--textures-4x-zip and --textures-4x-version cannot be combined"
	exit $?
fi
if (( MGS2_TEXTURE_2X_SELECTED && MGS2_TEXTURE_4X_SELECTED )); then
	mgs_cli_error "only one Community Bugfix texture add-on may be selected"
	exit $?
fi
if (( MGS_CLI_RESET_INI && ! MGS2_WANT_COMMUNITY_BUGFIX )); then
	mgs_cli_error "--reset-ini requires the Community Bugfix base package"
	exit $?
fi

TARGET=$(mgs_installer_resolve_target "$APPID" "$GAME_MARKER")

if (( MGS_CLI_LIST )); then
	mgs_info "Metal Gear Solid 2: $TARGET"
	if mgs_state_has_state "$TARGET" mgshdfix; then
		mgs_info "MGSHDFix: installed"
	else
		mgs_info "MGSHDFix: not installed by this installer"
	fi
	if mgs_state_has_state "$TARGET" mgs2communitybugfix; then
		mgs_info "MGS2 Community Bugfix base: installed"
	else
		mgs_info "MGS2 Community Bugfix base: not installed by this installer"
	fi
	if mgs_state_has_state "$TARGET" mgs2communitybugfix2x; then
		mgs_info "MGS2 Community Bugfix 2x texture add-on: installed"
	else
		mgs_info "MGS2 Community Bugfix 2x texture add-on: not installed by this installer"
	fi
	if mgs_state_has_state "$TARGET" mgs2communitybugfix4x; then
		mgs_info "MGS2 Community Bugfix 4x texture add-on: installed"
	else
		mgs_info "MGS2 Community Bugfix 4x texture add-on: not installed by this installer"
	fi
	exit 0
fi

if (( MGS_CLI_SET_LAUNCH_OPTIONS )); then
	mgs_installer_set_launch_options "$APPID" "$OVERRIDES"
	exit $?
fi

if (( MGS_CLI_UNINSTALL )); then
	UNINSTALLED=0
	if mgs_state_uninstall "$TARGET" mgs2communitybugfix4x "$MGS_CLI_DRY_RUN"; then
		mgs_info "MGS2 Community Bugfix 4x texture add-on removed from $TARGET"
		UNINSTALLED=1
	fi
	if mgs_state_uninstall "$TARGET" mgs2communitybugfix2x "$MGS_CLI_DRY_RUN"; then
		mgs_info "MGS2 Community Bugfix 2x texture add-on removed from $TARGET"
		UNINSTALLED=1
	fi
	if mgs_state_uninstall "$TARGET" mgs2communitybugfix "$MGS_CLI_DRY_RUN"; then
		mgs_info "MGS2 Community Bugfix base removed from $TARGET"
		UNINSTALLED=1
	fi
	if mgs_state_uninstall "$TARGET" mgshdfix "$MGS_CLI_DRY_RUN"; then
		mgs_info "MGSHDFix removed from $TARGET"
		UNINSTALLED=1
	fi
	if (( ! UNINSTALLED )); then
		mgs_warn "No tracked MGS2 components were found in $TARGET"
		exit 3
	fi
	mgs_info "MGSHDFix.settings was preserved because it is user-generated."
	exit 0
fi

mgs_require_command python3
mgs_require_command curl
mgs_installer_create_workspace mgs2

mgs_hdfix_acquire "$MGS_WORK_DIR"
if (( MGS2_WANT_COMMUNITY_BUGFIX )); then
	mgs2_bugfix_acquire_base "$MGS_WORK_DIR" \
		"$MGS2_COMMUNITY_BUGFIX_ZIP" "$MGS2_COMMUNITY_BUGFIX_VERSION"
fi
if [[ -n $MGS2_TEXTURE_PACK ]]; then
	case "$MGS2_TEXTURE_PACK" in
		2x)
			mgs2_bugfix_acquire_textures "$MGS_WORK_DIR" 2x \
				"$MGS2_TEXTURE_2X_ZIP" "$MGS2_TEXTURE_2X_VERSION"
			;;
		4x)
			mgs2_bugfix_acquire_textures "$MGS_WORK_DIR" 4x \
				"$MGS2_TEXTURE_4X_ZIP" "$MGS2_TEXTURE_4X_VERSION"
			;;
	esac
fi

mgs_step "Installing MGSHDFix into $TARGET"
mgs_hdfix_install "$TARGET" "$MGS_CLI_DRY_RUN"
if (( MGS2_WANT_COMMUNITY_BUGFIX )); then
	mgs_step "Installing MGS2 Community Bugfix base into $TARGET"
	mgs2_bugfix_install_base "$TARGET" "$MGS_CLI_RESET_INI" "$MGS_CLI_DRY_RUN"
fi
if [[ -n $MGS2_TEXTURE_PACK ]]; then
	OTHER_TEXTURE_PACK=
	case "$MGS2_TEXTURE_PACK" in
		2x) OTHER_TEXTURE_PACK=4x ;;
		4x) OTHER_TEXTURE_PACK=2x ;;
	esac
	if mgs_state_has_state "$TARGET" \
		"$(mgs2_texture_component "$OTHER_TEXTURE_PACK")"; then
		mgs_step "Removing previously tracked $(mgs2_texture_label "$OTHER_TEXTURE_PACK")"
		mgs_state_uninstall "$TARGET" \
			"$(mgs2_texture_component "$OTHER_TEXTURE_PACK")" "$MGS_CLI_DRY_RUN"
	fi
	mgs_step "Installing $(mgs2_texture_label "$MGS2_TEXTURE_PACK") into $TARGET"
	mgs2_bugfix_install_textures "$TARGET" "$MGS2_TEXTURE_PACK" "$MGS_CLI_DRY_RUN"
fi

if (( MGS_CLI_DRY_RUN )); then
	mgs_info "Dry run complete; nothing was written."
	exit 0
fi

CONFIG_TOOL_REL=$(mgs_hdfix_config_tool "$MGS_HDFIX_SOURCE" || true)
COMMUNITY_MESSAGE=
COMMUNITY_CONFIG_PATH=
COMMUNITY_NOTE_PATH="  not created (Community Bugfix base was not selected)"
COMMUNITY_INI_SUMMARY=
TEXTURE_MESSAGE=
if [[ -n $MGS2_TEXTURE_PACK ]]; then
	TEXTURE_MESSAGE="$(mgs2_texture_label "$MGS2_TEXTURE_PACK") is installed."
fi
if (( MGS2_WANT_COMMUNITY_BUGFIX )); then
	COMMUNITY_MESSAGE="MGS2 Community Bugfix Compilation base is installed."
	COMMUNITY_CONFIG_PATH="  $TARGET/plugins/MGS2-Community-Bugfix-Compilation.ini"
	COMMUNITY_NOTE_PATH="  $TARGET/$MGS2_MOD_ORDER_NOTE"
	COMMUNITY_INI_SUMMARY="The Community Bugfix INI is preserved by default and reset only with --reset-ini."
fi

cat <<EOF

MGSHDFix is installed.
${COMMUNITY_MESSAGE:+$COMMUNITY_MESSAGE
}${TEXTURE_MESSAGE:+$TEXTURE_MESSAGE
}

Steam launch options:
  WINEDLLOVERRIDES="$OVERRIDES" %command%

Set them with Steam closed:
  $0 --path "$TARGET" --set-launch-options

In the game's launcher, leave Internal Resolution and Internal Upscaling set
to Default / Original. MGSHDFix handles resolution itself.

Configuration tool:
  ${CONFIG_TOOL_REL:+$TARGET/$CONFIG_TOOL_REL}
  ${CONFIG_TOOL_REL:-MGSHDFix configuration tool not found in this release.}

On Steam Deck/Linux, the configuration tool requires Protontricks. Select any
game prefix when prompted. If the list is empty, add the tool as a non-Steam
game and launch it through Steam once.

Configuration files:
${COMMUNITY_CONFIG_PATH:+$COMMUNITY_CONFIG_PATH
}  $TARGET/plugins/MGSHDFix.settings

Recommended mod order note:
$COMMUNITY_NOTE_PATH

Keep this order when using a mod manager:
  1. MGSHDFix
  2. Knight_Killer's MGS2 Better Audio Mod
  3. MGS2 Community Bugfix Compilation - Base
  4. MGS2 Community Bugfix Compilation - AI Upscaled Texture Add-on (if installed)
  5. MGS2 Demastered Texture Pack (if installed)
  6. All other mods

The installer generates MGSHDFix.settings and preserves it on update/uninstall.
${COMMUNITY_INI_SUMMARY:+$COMMUNITY_INI_SUMMARY
}

Uninstall:
  $0 --path "$TARGET" --uninstall
EOF
