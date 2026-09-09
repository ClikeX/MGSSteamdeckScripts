#!/usr/bin/env bash

set -euo pipefail

INSTALLER_DIR=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
		pwd -P
)
# shellcheck source=util/legacy-wrapper.bash
source "$INSTALLER_DIR/../util/legacy-wrapper.bash"

mgs_legacy_extract_game all "$@" || exit $?
mgs_legacy_replace_option --crouch-zip --crouchwalk-zip

case "$MGS_LEGACY_GAME" in
	mgs2)
		for option in "${MGS_LEGACY_ARGS[@]}"; do
			case "$option" in
				--no-crouchwalk|--crouchwalk-zip|--crouchwalk-zip=*|\
				--qcamo|--qcamo-zip|--qcamo-zip=*|\
				--qcamo-version|--qcamo-version=*)
					printf 'error: MGS3 component options apply only to MGS3\n' >&2
					exit 64
					;;
			esac
		done
		mgs_legacy_exec "$INSTALLER_DIR/mgs2/install-mgs2.bash"
		;;
	mgs3)
		mgs_legacy_exec "$INSTALLER_DIR/mgs3/install-mgs3.bash"
		;;
	all|"")
		mgs_legacy_warn "the per-game MGSHDFix installers"
		printf '%s\n' \
			'error: the legacy multi-game MGSHDFix command is ambiguous.' \
			'Run these per-game commands instead:' \
			'  ./installers/mgs2/install-mgs2.bash' \
			'  ./installers/mgs3/install-mgs3.bash' >&2
		exit 64
		;;
	*)
		printf 'error: unknown legacy game selection: %s\n' \
			"$MGS_LEGACY_GAME" >&2
		exit 64
		;;
esac
