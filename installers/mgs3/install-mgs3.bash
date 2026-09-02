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

readonly APPID=2131650
readonly GAME_MARKER="METAL GEAR SOLID3.exe"
readonly OVERRIDES='wininet=n,b;winhttp=n,b'

MGS3_WANT_CROUCHWALK=1
MGS3_CROUCHWALK_ZIP=
MGS3_CROUCHWALK_VERSION=

usage() {
	cat <<'EOF'
Install or update MGSHDFix and MGS3CrouchWalk for Metal Gear Solid 3.

Usage: install-mgs3.bash [OPTIONS]

  -h, --help                    Show this help
  -l, --list                    Show the game and component install state
  -n, --dry-run                 Print actions without changing files
      --uninstall               Remove tracked components and restore backups
  -y, --yes                     Accept a missing marker or edit while Steam runs
  -p, --path PATH               Use an explicit game directory
      --zip PATH                Use a local MGSHDFix ZIP
  -v, --version TAG             Install a specific MGSHDFix GitHub release
      --no-crouchwalk           Install only MGSHDFix
      --crouchwalk-zip PATH     Use a local MGS3CrouchWalk ZIP
      --crouchwalk-version TAG  Install a specific CrouchWalk GitHub release
      --reset-ini               Replace MGS3CrouchWalk.ini with stock defaults
      --set-launch-options      Merge required DLL overrides into Steam config
      --user ACCOUNT_ID         Select a Steam userdata account
EOF
}

mgs3_parse_option() {
	local value

	case "$1" in
		--no-crouchwalk)
			MGS3_WANT_CROUCHWALK=0
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=1
			;;
		--crouchwalk-zip)
			value=$(mgs_cli_value "$1" "${2-}") || return
			MGS3_CROUCHWALK_ZIP=$value
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=2
			;;
		--crouchwalk-zip=*)
			value=$(mgs_cli_value --crouchwalk-zip "${1#*=}") || return
			MGS3_CROUCHWALK_ZIP=$value
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=1
			;;
		--crouchwalk-version)
			value=$(mgs_cli_value "$1" "${2-}") || return
			MGS3_CROUCHWALK_VERSION=$value
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=2
			;;
		--crouchwalk-version=*)
			value=$(mgs_cli_value --crouchwalk-version "${1#*=}") || return
			MGS3_CROUCHWALK_VERSION=$value
			mgs_cli_mark_install_selection
			MGS_CLI_CONSUMED=1
			;;
		*) return 1 ;;
	esac
}

mgs_cli_parse mgs3_parse_option "$@" || exit $?

if (( MGS_CLI_HELP )); then
	usage
	exit 0
fi
if [[ -n $MGS3_CROUCHWALK_ZIP && -n $MGS3_CROUCHWALK_VERSION ]]; then
	mgs_cli_error "--crouchwalk-zip and --crouchwalk-version cannot be combined"
	exit $?
fi
if (( ! MGS3_WANT_CROUCHWALK )) &&
	[[ -n $MGS3_CROUCHWALK_ZIP || -n $MGS3_CROUCHWALK_VERSION ]]; then
	mgs_cli_error "CrouchWalk source options cannot be used with --no-crouchwalk"
	exit $?
fi
if (( MGS_CLI_RESET_INI && ! MGS3_WANT_CROUCHWALK )); then
	mgs_cli_error "--reset-ini requires MGS3CrouchWalk to be selected"
	exit $?
fi

TARGET=$(mgs_installer_resolve_target "$APPID" "$GAME_MARKER")

if (( MGS_CLI_LIST )); then
	mgs_info "Metal Gear Solid 3: $TARGET"
	for COMPONENT in mgshdfix mgs3crouchwalk; do
		if mgs_state_has_state "$TARGET" "$COMPONENT"; then
			mgs_info "$COMPONENT: installed"
		else
			mgs_info "$COMPONENT: not installed by this installer"
		fi
	done
	exit 0
fi

if (( MGS_CLI_SET_LAUNCH_OPTIONS )); then
	mgs_installer_set_launch_options "$APPID" "$OVERRIDES"
	exit $?
fi

if (( MGS_CLI_UNINSTALL )); then
	UNINSTALLED=0
	if mgs_state_uninstall "$TARGET" mgs3crouchwalk "$MGS_CLI_DRY_RUN"; then
		mgs_info "MGS3CrouchWalk removed from $TARGET"
		UNINSTALLED=1
	fi
	if mgs_state_uninstall "$TARGET" mgshdfix "$MGS_CLI_DRY_RUN"; then
		mgs_info "MGSHDFix removed from $TARGET"
		UNINSTALLED=1
	fi
	if (( ! UNINSTALLED )); then
		mgs_warn "No tracked MGS3 components were found in $TARGET"
		exit 3
	fi
	mgs_info "MGSHDFix.settings was preserved because it is user-generated."
	exit 0
fi

mgs_require_command python3
mgs_require_command curl
mgs_installer_create_workspace mgs3
mgs_hdfix_acquire "$MGS_WORK_DIR"

CROUCHWALK_SOURCE=
if (( MGS3_WANT_CROUCHWALK )); then
	if [[ -n $MGS3_CROUCHWALK_ZIP ]]; then
		CROUCHWALK_ZIP=$(
			mgs_installer_absolute_file "$MGS3_CROUCHWALK_ZIP"
		)
		mgs_step "Using local MGS3CrouchWalk archive $(basename -- "$CROUCHWALK_ZIP")"
	else
		mgs_step "Resolving MGS3CrouchWalk release"
		IFS=$'\t' read -r CROUCH_TAG CROUCH_ASSET CROUCH_URL < <(
			mgs_installer_github_release cipherxof/MGS3CrouchWalk \
				'MGS3(CrouchWalk|_CrouchWalk)' "" '\.zip$' \
				"$MGS3_CROUCHWALK_VERSION"
		)
		[[ -n ${CROUCH_URL:-} ]] ||
			mgs_die "no MGS3CrouchWalk release asset was resolved"
		mgs_info "Release: $CROUCH_TAG"
		mgs_info "Asset: $CROUCH_ASSET"
		CROUCHWALK_ZIP=$MGS_WORK_DIR/crouchwalk.zip
		mgs_installer_download "$CROUCH_URL" "$CROUCHWALK_ZIP"
	fi

	mgs_step "Validating and extracting MGS3CrouchWalk"
	CROUCHWALK_SOURCE=$(
		mgs_installer_extract_archive "$CROUCHWALK_ZIP" \
			"$MGS_WORK_DIR/crouchwalk"
	)
fi

mgs_step "Installing MGSHDFix into $TARGET"
mgs_hdfix_install "$TARGET" "$MGS_CLI_DRY_RUN"

if (( MGS3_WANT_CROUCHWALK )); then
	CROUCHWALK_INI_PATHS=(MGS3CrouchWalk.ini)
	CROUCHWALK_STALE_PATHS=()
	mgs_step "Installing MGS3CrouchWalk into $TARGET"
	mgs_payload_install "$TARGET" "$CROUCHWALK_SOURCE" mgs3crouchwalk \
		"$MGS_CLI_RESET_INI" "$MGS_CLI_DRY_RUN" '^d3d11\.dll$' \
		'(^|/)MGS3CrouchWalk\.asi$' CROUCHWALK_INI_PATHS \
		CROUCHWALK_STALE_PATHS
fi

if (( MGS_CLI_DRY_RUN )); then
	mgs_info "Dry run complete; nothing was written."
	exit 0
fi

CONFIG_TOOL_REL=$(mgs_hdfix_config_tool "$MGS_HDFIX_SOURCE" || true)

cat <<EOF

MGS3 components are installed.

Steam launch options:
  WINEDLLOVERRIDES="$OVERRIDES" %command%

Set them with Steam closed:
  $0 --path "$TARGET" --set-launch-options

Do not add a d3d11 override. CrouchWalk's duplicate loader was excluded, and
MGSHDFix's wininet/winhttp loader loads its ASI.

Leave Internal Resolution and Internal Upscaling at Default / Original.

MGSHDFix configuration tool:
  ${CONFIG_TOOL_REL:+$TARGET/$CONFIG_TOOL_REL}
  ${CONFIG_TOOL_REL:-MGSHDFix configuration tool not found in this release.}

The MGSHDFix tool requires Protontricks on Linux. It generates
MGSHDFix.settings, which updates and uninstall preserve.
EOF

if (( MGS3_WANT_CROUCHWALK )); then
	cat <<EOF

MGS3CrouchWalk configuration:
  $TARGET/MGS3CrouchWalk.ini

Its localized animation archives are tracked separately and backed up before
replacement.
EOF
fi

cat <<EOF

MGSHDFix also applies fixes to Metal Gear and Metal Gear 2: Solid Snake (MSX),
which are included inside this MGS3 Steam installation.

Uninstall:
  $0 --path "$TARGET" --uninstall
EOF
