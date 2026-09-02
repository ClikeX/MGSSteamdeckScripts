#!/usr/bin/env bash

mgs_legacy_warn() {
	printf 'warn: %s is deprecated; use %s\n' \
		"$(basename -- "$0")" "$1" >&2
}

mgs_legacy_extract_game() {
	local default_game=$1
	shift
	local option

	MGS_LEGACY_GAME=$default_game
	MGS_LEGACY_ARGS=()
	while (( $# )); do
		option=$1
		case "$option" in
			--game|-g)
				(( $# >= 2 )) || {
					printf 'error: %s needs a value\n' "$option" >&2
					return 64
				}
				MGS_LEGACY_GAME=$2
				shift 2
				;;
			--game=*)
				MGS_LEGACY_GAME=${option#*=}
				shift
				;;
			*)
				MGS_LEGACY_ARGS+=("$option")
				shift
				;;
		esac
	done
}

mgs_legacy_has_exclusive_mode() {
	local option

	for option in "${MGS_LEGACY_ARGS[@]}"; do
		case "$option" in
			-h|--help|-l|--list|--uninstall|--set-launch-options|--write-settings)
				return 0
				;;
		esac
	done
	return 1
}

mgs_legacy_has_option() {
	local wanted=$1
	local option

	for option in "${MGS_LEGACY_ARGS[@]}"; do
		[[ $option == "$wanted" ]] && return 0
	done
	return 1
}

mgs_legacy_replace_option() {
	local old=$1
	local new=$2
	local index

	for index in "${!MGS_LEGACY_ARGS[@]}"; do
		case "${MGS_LEGACY_ARGS[$index]}" in
			"$old") MGS_LEGACY_ARGS[$index]=$new ;;
			"$old"=*) MGS_LEGACY_ARGS[$index]="$new=${MGS_LEGACY_ARGS[$index]#*=}" ;;
		esac
	done
}

mgs_legacy_remove_option() {
	local unwanted=$1
	local option
	local -a kept=()

	for option in "${MGS_LEGACY_ARGS[@]}"; do
		[[ $option == "$unwanted" ]] || kept+=("$option")
	done
	MGS_LEGACY_ARGS=("${kept[@]}")
}

mgs_legacy_exec() {
	local target=$1
	shift

	mgs_legacy_warn "$target"
	exec "$target" "$@" "${MGS_LEGACY_ARGS[@]}"
}
