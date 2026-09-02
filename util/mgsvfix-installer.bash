#!/usr/bin/env bash

mgs_mgsvfix_usage() {
	cat <<EOF
Install or update MGSVFix for $MGS_GAME_NAME.

Usage: $(basename -- "$0") [OPTIONS]

  -h, --help                  Show this help
  -l, --list                  Show the detected game and install state
  -n, --dry-run               Print actions without changing files
      --uninstall             Remove tracked files and restore backups
  -y, --yes                   Accept a missing marker or edit while Steam runs
  -p, --path PATH             Use an explicit game directory
      --zip PATH              Install from a local MGSVFix ZIP
  -v, --version TAG           Install a specific Codeberg release
      --reset-ini             Replace MGSVFix.ini with stock defaults
      --set-launch-options    Merge the required DLL override into Steam config
      --user ACCOUNT_ID       Select a Steam userdata account
EOF
}

mgs_mgsvfix_parse_option() {
	return 1
}

mgs_mgsvfix_main() {
	local target zip source release_tag asset_name asset_url status
	local -a mgsvfix_ini_paths=(MGSVFix.ini)
	local -a mgsvfix_stale_paths=(winmm.dll dinput8.dll MGSVFix.asi)

	mgs_cli_parse mgs_mgsvfix_parse_option "$@" || return

	if (( MGS_CLI_HELP )); then
		mgs_mgsvfix_usage
		return 0
	fi

	target=$(mgs_installer_resolve_target "$MGS_GAME_APPID" "$MGS_GAME_MARKER") ||
		return

	if (( MGS_CLI_LIST )); then
		mgs_info "$MGS_GAME_NAME: $target"
		if mgs_state_has_state "$target" mgsvfix; then
			mgs_info "MGSVFix: installed"
		else
			mgs_info "MGSVFix: not installed by this installer"
		fi
		return 0
	fi

	if (( MGS_CLI_SET_LAUNCH_OPTIONS )); then
		mgs_installer_set_launch_options "$MGS_GAME_APPID" 'winmm=n,b'
		return
	fi

	if (( MGS_CLI_UNINSTALL )); then
		if mgs_state_uninstall "$target" mgsvfix "$MGS_CLI_DRY_RUN"; then
			mgs_info "MGSVFix removed from $target"
			mgs_info "Remove its WINEDLLOVERRIDES entry from Steam if no other mod needs it."
			return 0
		else
			status=$?
		fi
		if (( status == 3 )); then
			mgs_warn "MGSVFix is not tracked in $target"
		fi
		return "$status"
	fi

	mgs_require_command python3
	mgs_require_command curl
	mgs_installer_create_workspace mgsvfix

	if [[ -n $MGS_CLI_ZIP ]]; then
		zip=$(mgs_installer_absolute_file "$MGS_CLI_ZIP") || return
		mgs_step "Using local MGSVFix archive $(basename -- "$zip")"
	else
		mgs_step "Resolving MGSVFix release"
		IFS=$'\t' read -r release_tag asset_name asset_url < <(
			mgs_installer_forgejo_release https://codeberg.org Lyall/MGSVFix \
				MGSVFix
		)
		[[ -n ${asset_url:-} ]] ||
			mgs_die "no MGSVFix release asset was resolved"
		mgs_info "Release: $release_tag"
		mgs_info "Asset: $asset_name"
		zip=$MGS_WORK_DIR/mgsvfix.zip
		mgs_installer_download "$asset_url" "$zip"
	fi

	mgs_step "Validating and extracting MGSVFix"
	source=$(mgs_installer_extract_archive "$zip" "$MGS_WORK_DIR/payload") ||
		return

	mgs_step "Installing MGSVFix into $target"
	mgs_payload_install "$target" "$source" mgsvfix "$MGS_CLI_RESET_INI" \
		"$MGS_CLI_DRY_RUN" "" '(^|/)MGSVFix\.asi$' mgsvfix_ini_paths \
		mgsvfix_stale_paths

	if (( MGS_CLI_DRY_RUN )); then
		mgs_info "Dry run complete; nothing was written."
		return 0
	fi

	cat <<EOF

MGSVFix is installed.

Steam launch options:
  WINEDLLOVERRIDES="winmm=n,b" %command%

Set them with Steam closed:
  $0 --path "$target" --set-launch-options

Configuration:
  $target/MGSVFix.ini

Uninstall:
  $0 --path "$target" --uninstall
EOF
}
