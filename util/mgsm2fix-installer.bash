#!/usr/bin/env bash

mgs_mgsm2fix_usage() {
	cat <<EOF
Install or update MGSM2Fix for $MGS_GAME_NAME.

Usage: $(basename -- "$0") [OPTIONS]

  -h, --help                  Show this help
  -l, --list                  Show the detected game and install state
  -n, --dry-run               Print actions without changing files
      --uninstall             Remove tracked files and restore backups
  -y, --yes                   Accept a missing marker or edit while Steam runs
  -p, --path PATH             Use an explicit game directory
      --zip PATH              Install from a local MGSM2Fix ZIP
  -v, --version TAG           Install a specific GitHub release
      --reset-ini             Replace MGSM2Fix.ini with stock defaults
      --set-launch-options    Merge required DLL overrides into Steam config
      --user ACCOUNT_ID       Select a Steam userdata account
EOF
}

mgs_mgsm2fix_parse_option() {
	return 1
}

mgs_mgsm2fix_acquire() {
	local workspace=$1
	local zip_override=${2-}
	local version=${3-}
	local zip release_tag asset_name asset_url

	mkdir -p "$workspace"
	if [[ -n $zip_override ]]; then
		zip=$(mgs_installer_absolute_file "$zip_override") || return
		mgs_step "Using local MGSM2Fix archive $(basename -- "$zip")"
	else
		mgs_step "Resolving MGSM2Fix release"
		IFS=$'\t' read -r release_tag asset_name asset_url < <(
			mgs_installer_github_release nuggslet/MGSM2Fix MGSM2Fix "" \
				'\.zip$' "$version"
		)
		[[ -n ${asset_url:-} ]] ||
			mgs_die "no MGSM2Fix release asset was resolved"
		mgs_info "Release: $release_tag"
		mgs_info "Asset: $asset_name"
		zip=$workspace/mgsm2fix.zip
		mgs_installer_download "$asset_url" "$zip"
	fi

	mgs_step "Validating and extracting MGSM2Fix"
	MGS_MGSM2FIX_SOURCE=$(
		mgs_installer_extract_archive "$zip" "$workspace/mgsm2fix"
	) || return
}

mgs_mgsm2fix_install() {
	local target=$1
	local reset_ini=$2
	local dry_run=$3
	local -a mgsm2fix_ini_paths=(MGSM2Fix.ini)
	local -a mgsm2fix_stale_paths=(
		MGSM2Fix.asi
		d3d11-x64.SHA512
		dinput8-Win32.SHA512
	)

	mgs_payload_install "$target" "$MGS_MGSM2FIX_SOURCE" mgsm2fix \
		"$reset_ini" "$dry_run" "" '\.(asi|dll)$' mgsm2fix_ini_paths \
		mgsm2fix_stale_paths
}

mgs_mgsm2fix_main() {
	local target status

	mgs_cli_parse mgs_mgsm2fix_parse_option "$@" || return

	if (( MGS_CLI_HELP )); then
		mgs_mgsm2fix_usage
		return 0
	fi

	target=$(mgs_installer_resolve_target "$MGS_GAME_APPID" "$MGS_GAME_MARKER") ||
		return

	if (( MGS_CLI_LIST )); then
		mgs_info "$MGS_GAME_NAME: $target"
		if mgs_state_has_state "$target" mgsm2fix; then
			mgs_info "MGSM2Fix: installed"
		else
			mgs_info "MGSM2Fix: not installed by this installer"
		fi
		return 0
	fi

	if (( MGS_CLI_SET_LAUNCH_OPTIONS )); then
		mgs_installer_set_launch_options "$MGS_GAME_APPID" \
			'dinput8=n,b;d3d11=n,b'
		return
	fi

	if (( MGS_CLI_UNINSTALL )); then
		if mgs_state_uninstall "$target" mgsm2fix "$MGS_CLI_DRY_RUN"; then
			mgs_info "MGSM2Fix removed from $target"
			mgs_info "Remove its WINEDLLOVERRIDES entries from Steam if no other mod needs them."
			return 0
		else
			status=$?
		fi
		if (( status == 3 )); then
			mgs_warn "MGSM2Fix is not tracked in $target"
		fi
		return "$status"
	fi

	mgs_require_command python3
	mgs_require_command curl
	mgs_installer_create_workspace mgsm2fix
	mgs_mgsm2fix_acquire "$MGS_WORK_DIR" "$MGS_CLI_ZIP" "$MGS_CLI_VERSION"

	mgs_step "Installing MGSM2Fix into $target"
	mgs_mgsm2fix_install "$target" "$MGS_CLI_RESET_INI" "$MGS_CLI_DRY_RUN"

	if (( MGS_CLI_DRY_RUN )); then
		mgs_info "Dry run complete; nothing was written."
		return 0
	fi

	cat <<EOF

MGSM2Fix is installed.

Steam launch options:
  WINEDLLOVERRIDES="dinput8=n,b;d3d11=n,b" %command%

Set them with Steam closed:
  $0 --path "$target" --set-launch-options

Configuration:
  $target/MGSM2Fix.ini

Uninstall:
  $0 --path "$target" --uninstall
EOF
}
