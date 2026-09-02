#!/usr/bin/env bash

mgs_cli_reset() {
	MGS_CLI_HELP=0
	MGS_CLI_LIST=0
	MGS_CLI_DRY_RUN=0
	MGS_CLI_UNINSTALL=0
	MGS_CLI_ASSUME_YES=0
	MGS_CLI_PATH=
	MGS_CLI_ZIP=
	MGS_CLI_VERSION=
	MGS_CLI_RESET_INI=0
	MGS_CLI_SET_LAUNCH_OPTIONS=0
	MGS_CLI_STEAM_USER=
	MGS_CLI_EXCLUSIVE_MODE=
	MGS_CLI_EXCLUSIVE_COUNT=0
	MGS_CLI_INSTALL_SELECTION=0
	MGS_CLI_CONSUMED=0
}

mgs_cli_error() {
	printf 'error: %s\n' "$*" >&2
	return 64
}

mgs_cli_set_exclusive() {
	local mode=$1

	if [[ -n $MGS_CLI_EXCLUSIVE_MODE && $MGS_CLI_EXCLUSIVE_MODE != "$mode" ]]; then
		MGS_CLI_EXCLUSIVE_COUNT=$((MGS_CLI_EXCLUSIVE_COUNT + 1))
	else
		MGS_CLI_EXCLUSIVE_MODE=$mode
		MGS_CLI_EXCLUSIVE_COUNT=1
	fi
}

mgs_cli_mark_install_selection() {
	MGS_CLI_INSTALL_SELECTION=1
}

mgs_cli_value() {
	local option=$1
	local value=${2-}

	if [[ -z $value ]]; then
		mgs_cli_error "$option needs a value"
		return 64
	fi

	printf '%s\n' "$value"
}

mgs_cli_parse() {
	local game_parser=${1-}
	local option value
	shift || true

	mgs_cli_reset

	while (( $# )); do
		option=$1
		case "$option" in
			-h|--help)
				MGS_CLI_HELP=1
				mgs_cli_set_exclusive help
				shift
				;;
			-l|--list)
				MGS_CLI_LIST=1
				mgs_cli_set_exclusive list
				shift
				;;
			-n|--dry-run)
				MGS_CLI_DRY_RUN=1
				shift
				;;
			--uninstall)
				MGS_CLI_UNINSTALL=1
				mgs_cli_set_exclusive uninstall
				shift
				;;
			-y|--yes)
				MGS_CLI_ASSUME_YES=1
				shift
				;;
			-p|--path)
				value=$(mgs_cli_value "$option" "${2-}") || return
				MGS_CLI_PATH=$value
				shift 2
				;;
			--path=*)
				value=$(mgs_cli_value --path "${option#*=}") || return
				MGS_CLI_PATH=$value
				shift
				;;
			--zip)
				value=$(mgs_cli_value "$option" "${2-}") || return
				MGS_CLI_ZIP=$value
				mgs_cli_mark_install_selection
				shift 2
				;;
			--zip=*)
				value=$(mgs_cli_value --zip "${option#*=}") || return
				MGS_CLI_ZIP=$value
				mgs_cli_mark_install_selection
				shift
				;;
			-v|--version)
				value=$(mgs_cli_value "$option" "${2-}") || return
				MGS_CLI_VERSION=$value
				mgs_cli_mark_install_selection
				shift 2
				;;
			--version=*)
				value=$(mgs_cli_value --version "${option#*=}") || return
				MGS_CLI_VERSION=$value
				mgs_cli_mark_install_selection
				shift
				;;
			--reset-ini)
				MGS_CLI_RESET_INI=1
				mgs_cli_mark_install_selection
				shift
				;;
			--set-launch-options)
				MGS_CLI_SET_LAUNCH_OPTIONS=1
				mgs_cli_set_exclusive set-launch-options
				shift
				;;
			--user)
				value=$(mgs_cli_value "$option" "${2-}") || return
				MGS_CLI_STEAM_USER=$value
				shift 2
				;;
			--user=*)
				value=$(mgs_cli_value --user "${option#*=}") || return
				MGS_CLI_STEAM_USER=$value
				shift
				;;
			*)
				if [[ -z $game_parser ]] || ! declare -F "$game_parser" >/dev/null 2>&1; then
					mgs_cli_error "unknown argument: $option (try --help)"
					return 64
				fi
				MGS_CLI_CONSUMED=0
				if ! "$game_parser" "$@"; then
					mgs_cli_error "unknown argument: $option (try --help)"
					return 64
				fi
				if (( MGS_CLI_CONSUMED < 1 || MGS_CLI_CONSUMED > $# )); then
					mgs_cli_error "internal parser error for argument: $option"
					return 64
				fi
				shift "$MGS_CLI_CONSUMED"
				;;
		esac
	done

	if (( MGS_CLI_EXCLUSIVE_COUNT > 1 )); then
		mgs_cli_error "only one operation mode may be selected"
		return 64
	fi

	if [[ -n $MGS_CLI_EXCLUSIVE_MODE && $MGS_CLI_INSTALL_SELECTION -eq 1 ]]; then
		mgs_cli_error "install/update options cannot be used with --$MGS_CLI_EXCLUSIVE_MODE"
		return 64
	fi

	if [[ -n $MGS_CLI_STEAM_USER && $MGS_CLI_SET_LAUNCH_OPTIONS -ne 1 ]]; then
		mgs_cli_error "--user is valid only with --set-launch-options"
		return 64
	fi

	if [[ -n $MGS_CLI_ZIP && -n $MGS_CLI_VERSION ]]; then
		mgs_cli_error "--zip and --version cannot be used together"
		return 64
	fi

	return 0
}
