#!/usr/bin/env bash

mgs_patriotfix_usage() {
	cat <<EOF
Install or update MGSPatriotFix for $MGS_GAME_NAME.

Usage: $(basename -- "$0") [OPTIONS]

  -h, --help                  Show this help
  -l, --list                  Show the detected game and install state
  -n, --dry-run               Print actions without changing files
      --uninstall             Remove tracked files and restore backups
      --write-settings        Write a complete default settings file
  -y, --yes                   Overwrite settings or accept other warnings
  -p, --path PATH             Use an explicit game directory
      --zip PATH              Install from a local MGSPatriotFix ZIP
  -v, --version TAG           Install a specific GitHub release
      --set-launch-options    Merge required DLL overrides into Steam config
      --user ACCOUNT_ID       Select a Steam userdata account

MGSPatriotFix provides no release INI. --reset-ini is not supported.
EOF
}

mgs_patriotfix_parse_option() {
	case "$1" in
		--write-settings)
			MGS_PATRIOTFIX_WRITE_SETTINGS=1
			mgs_cli_set_exclusive write-settings
			MGS_CLI_CONSUMED=1
			;;
		*) return 1 ;;
	esac
}

mgs_patriotfix_main() {
	local target zip source release_tag asset_name asset_url status
	local config_tool_relative=
	local relative_path
	local -a settings_command
	local -a patriotfix_ini_paths=()
	local -a patriotfix_stale_paths=()

	MGS_PATRIOTFIX_WRITE_SETTINGS=0
	mgs_cli_parse mgs_patriotfix_parse_option "$@" || return

	if (( MGS_CLI_HELP )); then
		mgs_patriotfix_usage
		return 0
	fi
	if (( MGS_CLI_RESET_INI )); then
		mgs_cli_error "--reset-ini is not supported because MGSPatriotFix provides no INI"
		return
	fi

	target=$(mgs_installer_resolve_target "$MGS_GAME_APPID" "$MGS_GAME_MARKER") ||
		return

	if (( MGS_CLI_LIST )); then
		mgs_info "$MGS_GAME_NAME: $target"
		if mgs_state_has_state "$target" mgspatriotfix; then
			mgs_info "MGSPatriotFix: installed"
		else
			mgs_info "MGSPatriotFix: not installed by this installer"
		fi
		[[ -f $target/MGSPatriotFix.settings ]] &&
			mgs_info "MGSPatriotFix settings: present"
		return 0
	fi

	if (( MGS_CLI_SET_LAUNCH_OPTIONS )); then
		mgs_installer_set_launch_options "$MGS_GAME_APPID" \
			'wininet=n,b;winhttp=n,b'
		return
	fi

	if (( MGS_PATRIOTFIX_WRITE_SETTINGS )); then
		mgs_require_command python3 || return
		settings_command=(
			"$MGS_UTIL_DIR/patriot_settings.py"
			"$target/MGSPatriotFix.settings"
			--game "$MGS_PATRIOTFIX_GAME_KEY"
		)
		(( MGS_CLI_ASSUME_YES )) && settings_command+=(--force)
		(( MGS_CLI_DRY_RUN )) && settings_command+=(--dry-run)
		"${settings_command[@]}"
		return
	fi

	if (( MGS_CLI_UNINSTALL )); then
		if mgs_state_uninstall "$target" mgspatriotfix "$MGS_CLI_DRY_RUN"; then
			mgs_info "MGSPatriotFix removed from $target"
			mgs_info "MGSPatriotFix.settings was preserved."
			mgs_info "Remove its WINEDLLOVERRIDES entries from Steam if no other mod needs them."
			return 0
		else
			status=$?
		fi
		if (( status == 3 )); then
			mgs_warn "MGSPatriotFix is not tracked in $target"
		fi
		return "$status"
	fi

	mgs_require_command python3
	mgs_require_command curl
	mgs_installer_create_workspace mgspatriotfix

	if [[ -n $MGS_CLI_ZIP ]]; then
		zip=$(mgs_installer_absolute_file "$MGS_CLI_ZIP") || return
		mgs_step "Using local MGSPatriotFix archive $(basename -- "$zip")"
	else
		mgs_step "Resolving MGSPatriotFix release"
		IFS=$'\t' read -r release_tag asset_name asset_url < <(
			mgs_installer_github_release ShizCalev/MGSPatriotFix \
				"$MGS_PATRIOTFIX_ASSET_MATCH" "$MGS_PATRIOTFIX_ASSET_REJECT"
		)
		[[ -n ${asset_url:-} ]] ||
			mgs_die "no MGSPatriotFix release asset was resolved for $MGS_GAME_NAME"
		mgs_info "Release: $release_tag"
		mgs_info "Asset: $asset_name"
		zip=$MGS_WORK_DIR/mgspatriotfix.zip
		mgs_installer_download "$asset_url" "$zip"
	fi

	mgs_step "Validating and extracting MGSPatriotFix"
	source=$(mgs_installer_extract_archive "$zip" "$MGS_WORK_DIR/payload") ||
		return

	mgs_step "Installing MGSPatriotFix into $target"
	mgs_payload_install "$target" "$source" mgspatriotfix 0 \
		"$MGS_CLI_DRY_RUN" '(^|/)MGSPatriotFix\.settings$' \
		'(^|/)MGSPatriotFix\.asi$' patriotfix_ini_paths \
		patriotfix_stale_paths

	if (( MGS_CLI_DRY_RUN )); then
		mgs_info "Dry run complete; nothing was written."
		return 0
	fi

	while IFS= read -r relative_path; do
		case "${relative_path,,}" in
			*config?tool*.exe) config_tool_relative=$relative_path ;;
		esac
	done < <(mgs_payload_files "$source")

	cat <<EOF

MGSPatriotFix is installed.

Steam launch options:
  WINEDLLOVERRIDES="wininet=n,b;winhttp=n,b" %command%

Set them with Steam closed:
  $0 --path "$target" --set-launch-options

Configuration tool:
  ${config_tool_relative:+$target/$config_tool_relative}
  ${config_tool_relative:-MGSPatriotFix configuration tool not found in this release.}

On Steam Deck/Linux, the configuration tool requires Protontricks. Select any
game prefix when prompted. If the list is empty, add the tool as a non-Steam
game and launch it through Steam once.

To generate complete default settings without the GUI:
  $0 --path "$target" --write-settings

Uninstall:
  $0 --path "$target" --uninstall
EOF
}
