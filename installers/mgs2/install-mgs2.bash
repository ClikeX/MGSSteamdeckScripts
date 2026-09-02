#!/usr/bin/env bash

set -euo pipefail

INSTALLER_DIR=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
		pwd -P
)
# shellcheck source=util/installer-core.bash
source "$INSTALLER_DIR/../../util/installer-core.bash"
mgs_installer_init "${BASH_SOURCE[0]}"

readonly APPID=2131640
readonly GAME_MARKER="METAL GEAR SOLID2.exe"
readonly COMPONENT=mgshdfix
readonly REPOSITORY=ShizCalev/MGSHDFix
readonly OVERRIDES='wininet=n,b;winhttp=n,b'

usage() {
	cat <<'EOF'
Install or update MGSHDFix for Metal Gear Solid 2: Master Collection Version.

Usage: install-mgs2.bash [OPTIONS]

  -h, --help                  Show this help
  -l, --list                  Show the detected game and install state
  -n, --dry-run               Print actions without changing files
      --uninstall             Remove tracked files and restore backups
  -y, --yes                   Accept a missing marker or edit while Steam runs
  -p, --path PATH             Use an explicit game directory
      --zip PATH              Install from a local MGSHDFix ZIP
  -v, --version TAG           Install a specific GitHub release
      --set-launch-options    Merge required DLL overrides into Steam config
      --user ACCOUNT_ID       Select a Steam userdata account

MGSHDFix has no release-provided INI. --reset-ini is not supported.
EOF
}

mgs2_parse_option() {
	return 1
}

mgs_cli_parse mgs2_parse_option "$@" || exit $?

if (( MGS_CLI_HELP )); then
	usage
	exit 0
fi
if (( MGS_CLI_RESET_INI )); then
	mgs_cli_error "--reset-ini is not supported because MGSHDFix provides no INI"
	exit $?
fi

TARGET=$(mgs_installer_resolve_target "$APPID" "$GAME_MARKER")

if (( MGS_CLI_LIST )); then
	mgs_info "Metal Gear Solid 2: $TARGET"
	if mgs_state_has_state "$TARGET" "$COMPONENT"; then
		mgs_info "MGSHDFix: installed"
	else
		mgs_info "MGSHDFix: not installed by this installer"
	fi
	exit 0
fi

if (( MGS_CLI_SET_LAUNCH_OPTIONS )); then
	mgs_installer_set_launch_options "$APPID" "$OVERRIDES"
	exit $?
fi

if (( MGS_CLI_UNINSTALL )); then
	if mgs_state_uninstall "$TARGET" "$COMPONENT" "$MGS_CLI_DRY_RUN"; then
		mgs_info "MGSHDFix removed from $TARGET"
		mgs_info "MGSHDFix.settings was preserved because it is user-generated."
		mgs_info "Remove its WINEDLLOVERRIDES entries from Steam if no other mod needs them."
		exit 0
	else
		status=$?
	fi
	if (( status == 3 )); then
		mgs_warn "MGSHDFix is not tracked in $TARGET"
	fi
	exit "$status"
fi

mgs_require_command python3
mgs_require_command curl
mgs_installer_create_workspace mgs2

if [[ -n $MGS_CLI_ZIP ]]; then
	ZIP=$(mgs_installer_absolute_file "$MGS_CLI_ZIP")
	mgs_step "Using local MGSHDFix archive $(basename -- "$ZIP")"
else
	mgs_step "Resolving MGSHDFix release"
	IFS=$'\t' read -r RELEASE_TAG ASSET_NAME ASSET_URL < <(
		mgs_installer_github_release "$REPOSITORY" MGSHDFix
	)
	[[ -n ${ASSET_URL:-} ]] || mgs_die "no MGSHDFix release asset was resolved"
	mgs_info "Release: $RELEASE_TAG"
	mgs_info "Asset: $ASSET_NAME"
	ZIP=$MGS_WORK_DIR/mgshdfix.zip
	mgs_installer_download "$ASSET_URL" "$ZIP"
fi

mgs_step "Validating and extracting MGSHDFix"
SOURCE=$(mgs_installer_extract_archive "$ZIP" "$MGS_WORK_DIR/payload")

MGSHDFIX_INI_PATHS=()
MGSHDFIX_STALE_PATHS=(
	d3d11.dll
	MGSHDFix.asi
	"MGSHDFix Config Tool.exe"
)

mgs_step "Installing MGSHDFix into $TARGET"
mgs_payload_install "$TARGET" "$SOURCE" "$COMPONENT" 0 "$MGS_CLI_DRY_RUN" \
	'(^|/)logs/|(^|/)MGSHDFix\.settings$' \
	'(^|/)MGSHDFix\.asi$' MGSHDFIX_INI_PATHS MGSHDFIX_STALE_PATHS

if (( MGS_CLI_DRY_RUN )); then
	mgs_info "Dry run complete; nothing was written."
	exit 0
fi

CONFIG_TOOL_REL=
while IFS= read -r RELATIVE_PATH; do
	case "${RELATIVE_PATH,,}" in
		*config?tool*.exe) CONFIG_TOOL_REL=$RELATIVE_PATH ;;
	esac
done < <(mgs_payload_files "$SOURCE" '(^|/)logs/')

cat <<EOF

MGSHDFix is installed.

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

The tool generates MGSHDFix.settings; updates and uninstall preserve that file.

Uninstall:
  $0 --path "$TARGET" --uninstall
EOF
