#!/usr/bin/env bash

set -euo pipefail

INSTALLER_DIR=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
		pwd -P
)
# shellcheck source=util/legacy-wrapper.bash
source "$INSTALLER_DIR/../util/legacy-wrapper.bash"

mgs_legacy_extract_game mgs4 "$@" || exit $?
mgs_legacy_remove_option --no-build

case "$MGS_LEGACY_GAME" in
	mgs4)
		mgs_legacy_exec "$INSTALLER_DIR/mgs4/install-mgs4.bash"
		;;
	pw)
		for option in "${MGS_LEGACY_ARGS[@]}"; do
			case "$option" in
				--modloader|--modloader-file|--modloader-file=*)
					printf 'error: MGS4 Mod Loader options do not apply to Peace Walker\n' >&2
					exit 64
					;;
			esac
		done
		mgs_legacy_exec "$INSTALLER_DIR/mgspw/install-mgspw.bash"
		;;
	*)
		printf 'error: unknown legacy game selection: %s\n' \
			"$MGS_LEGACY_GAME" >&2
		exit 64
		;;
esac
