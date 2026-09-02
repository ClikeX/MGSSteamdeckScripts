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
	if mgs_state_has_state "$TARGET" mgshdfix; then
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
	if mgs_state_uninstall "$TARGET" mgshdfix "$MGS_CLI_DRY_RUN"; then
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

mgs_hdfix_acquire "$MGS_WORK_DIR"

mgs_step "Installing MGSHDFix into $TARGET"
mgs_hdfix_install "$TARGET" "$MGS_CLI_DRY_RUN"

if (( MGS_CLI_DRY_RUN )); then
	mgs_info "Dry run complete; nothing was written."
	exit 0
fi

CONFIG_TOOL_REL=$(mgs_hdfix_config_tool "$MGS_HDFIX_SOURCE" || true)

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
