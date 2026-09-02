#!/usr/bin/env bash
#
# steam-path-from-appid — print the absolute install directory of a Steam AppID.
#
# Usage: steam-path-from-appid.bash <appid>
#
# Exit codes: 0 found, 1 error, 3 not installed, 64 bad usage.

MGS_STEAM_PATH_UTIL_DIR=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
		pwd -P
)
# shellcheck source=util/steam-libraries.bash
source "$MGS_STEAM_PATH_UTIL_DIR/steam-libraries.bash"

mgs_steam_path_from_appid_main() {
	local program=${0##*/}
	local status

	if (( $# != 1 )); then
		printf '%s: usage: %s <appid>\n' "$program" "$program" >&2
		return 64
	fi

	if mgs_steam_path_from_appid "$1"; then
		return 0
	else
		status=$?
	fi

	case "$status" in
		3) printf '%s: AppID %s is not installed\n' "$program" "$1" >&2 ;;
		64) : ;;
		*) printf '%s: could not resolve AppID %s\n' "$program" "$1" >&2 ;;
	esac
	return "$status"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
	set -uo pipefail
	mgs_steam_path_from_appid_main "$@"
	exit $?
fi
