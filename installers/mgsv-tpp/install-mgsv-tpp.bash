#!/usr/bin/env bash

set -euo pipefail

INSTALLER_DIR=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
		pwd -P
)
# shellcheck source=util/installer-core.bash
source "$INSTALLER_DIR/../../util/installer-core.bash"
mgs_installer_init "${BASH_SOURCE[0]}"
# shellcheck source=util/mgsvfix-installer.bash
source "$MGS_UTIL_DIR/mgsvfix-installer.bash"
# shellcheck source=util/infinite-heaven.bash
source "$MGS_UTIL_DIR/infinite-heaven.bash"

readonly APPID=287700
readonly GAME_MARKER=mgsvtpp.exe

MGS_TPP_IH_PREP=0
MGS_TPP_IH_RESTORE=0
MGS_TPP_IH_BACKUP_DIR=
MGS_TPP_IH_ZIPS=()

usage() {
	cat <<'EOF'
Install MGSVFix or run guided Infinite Heaven maintenance for The Phantom Pain.

Usage: install-mgsv-tpp.bash [OPTIONS]

  -h, --help                  Show this help
  -l, --list                  Show detected MGSVFix and Infinite Heaven state
  -n, --dry-run               Print actions without changing files
      --uninstall             Remove MGSVFix and restore tracked originals
  -y, --yes                   Accept a missing marker or edit while Steam runs
  -p, --path PATH             Use an explicit game directory
      --zip PATH              Install from a local MGSVFix ZIP
  -v, --version TAG           Install a specific Codeberg MGSVFix release
      --reset-ini             Replace MGSVFix.ini with stock defaults
      --set-launch-options    Merge the required winmm override
      --user ACCOUNT_ID       Select a Steam userdata account
      --ih                    Back up vanilla archives and saves
      --ih-zip PATH           Stage an IH or IHHook ZIP; may be repeated
      --ih-backup-dir PATH    Store a new vanilla backup below PATH
      --ih-restore            Restore the default vanilla backup and remove mod/
EOF
}

mgs_tpp_parse_option() {
	local value

	case "$1" in
		--ih)
			MGS_TPP_IH_PREP=1
			mgs_cli_set_exclusive ih
			MGS_CLI_CONSUMED=1
			;;
		--ih-zip)
			value=$(mgs_cli_value "$1" "${2-}") || return
			MGS_TPP_IH_ZIPS+=("$value")
			mgs_cli_set_exclusive ih
			MGS_CLI_CONSUMED=2
			;;
		--ih-zip=*)
			value=$(mgs_cli_value --ih-zip "${1#*=}") || return
			MGS_TPP_IH_ZIPS+=("$value")
			mgs_cli_set_exclusive ih
			MGS_CLI_CONSUMED=1
			;;
		--ih-backup-dir)
			value=$(mgs_cli_value "$1" "${2-}") || return
			MGS_TPP_IH_BACKUP_DIR=$value
			MGS_CLI_CONSUMED=2
			;;
		--ih-backup-dir=*)
			value=$(mgs_cli_value --ih-backup-dir "${1#*=}") || return
			MGS_TPP_IH_BACKUP_DIR=$value
			MGS_CLI_CONSUMED=1
			;;
		--ih-restore)
			MGS_TPP_IH_RESTORE=1
			mgs_cli_set_exclusive ih-restore
			MGS_CLI_CONSUMED=1
			;;
		*) return 1 ;;
	esac
}

mgs_cli_parse mgs_tpp_parse_option "$@" || exit $?

if (( MGS_CLI_HELP )); then
	usage
	exit 0
fi
if [[ -n $MGS_TPP_IH_BACKUP_DIR ]] && (( ! MGS_TPP_IH_PREP )); then
	mgs_cli_error "--ih-backup-dir is valid only with --ih"
	exit $?
fi
if (( MGS_TPP_IH_RESTORE )) && [[ -n $MGS_TPP_IH_BACKUP_DIR ]]; then
	mgs_cli_error "--ih-restore cannot be combined with --ih-backup-dir"
	exit $?
fi

TARGET=$(mgs_installer_resolve_target "$APPID" "$GAME_MARKER")

if (( MGS_CLI_LIST )); then
	mgs_info "Metal Gear Solid V: The Phantom Pain: $TARGET"
	if mgs_state_has_state "$TARGET" mgsvfix; then
		mgs_info "MGSVFix: installed"
	else
		mgs_info "MGSVFix: not installed by this installer"
	fi
	mgs_ih_report "$TARGET"
	exit 0
fi

if (( MGS_CLI_SET_LAUNCH_OPTIONS )); then
	mgs_installer_set_launch_options "$APPID" 'winmm=n,b'
	exit $?
fi

if (( MGS_CLI_UNINSTALL )); then
	if mgs_state_uninstall "$TARGET" mgsvfix "$MGS_CLI_DRY_RUN"; then
		mgs_info "MGSVFix removed from $TARGET"
		mgs_info "Infinite Heaven files were not changed."
		exit 0
	else
		status=$?
	fi
	(( status == 3 )) && mgs_warn "MGSVFix is not tracked in $TARGET"
	exit "$status"
fi

if (( MGS_TPP_IH_RESTORE )); then
	mgs_ih_restore "$TARGET" "$MGS_CLI_DRY_RUN"
	mgs_ih_report "$TARGET"
	exit 0
fi

if (( MGS_TPP_IH_PREP || ${#MGS_TPP_IH_ZIPS[@]} )); then
	if (( MGS_TPP_IH_PREP )); then
		mgs_ih_backup "$TARGET" "$MGS_TPP_IH_BACKUP_DIR" "$MGS_CLI_DRY_RUN"
	fi
	if (( ${#MGS_TPP_IH_ZIPS[@]} )); then
		mgs_require_command python3
		mgs_ih_stage "$TARGET" "$MGS_CLI_DRY_RUN" "${MGS_TPP_IH_ZIPS[@]}"
	fi
	mgs_ih_report "$TARGET" "$MGS_TPP_IH_BACKUP_DIR"
	mgs_ih_print_steps "$TARGET"
	exit 0
fi

mgs_require_command python3
mgs_require_command curl
mgs_installer_create_workspace mgsv-tpp
mgs_mgsvfix_acquire "$MGS_WORK_DIR" "$MGS_CLI_ZIP" "$MGS_CLI_VERSION"

mgs_step "Installing MGSVFix into $TARGET"
mgs_mgsvfix_install "$TARGET" "$MGS_CLI_RESET_INI" "$MGS_CLI_DRY_RUN"

if (( MGS_CLI_DRY_RUN )); then
	mgs_info "Dry run complete; nothing was written."
	exit 0
fi

cat <<EOF

MGSVFix is installed for The Phantom Pain.

Steam launch options:
  WINEDLLOVERRIDES="winmm=n,b" %command%

Set them with Steam closed:
  $0 --path "$TARGET" --set-launch-options

Configuration:
  $TARGET/MGSVFix.ini

Infinite Heaven preparation:
  $0 --path "$TARGET" --ih

Uninstall MGSVFix without changing Infinite Heaven:
  $0 --path "$TARGET" --uninstall
EOF
