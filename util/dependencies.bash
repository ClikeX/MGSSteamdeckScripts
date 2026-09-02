#!/usr/bin/env bash

mgs_has_command() {
	command -v "$1" >/dev/null 2>&1
}

mgs_require_command() {
	local command_name=$1

	if mgs_has_command "$command_name"; then
		return 0
	fi

	printf 'error: required command not found: %s\n' "$command_name" >&2
	return 1
}

mgs_require_one_of() {
	local command_name

	for command_name in "$@"; do
		if mgs_has_command "$command_name"; then
			printf '%s\n' "$command_name"
			return 0
		fi
	done

	printf 'error: required one of these commands: %s\n' "$*" >&2
	return 1
}
