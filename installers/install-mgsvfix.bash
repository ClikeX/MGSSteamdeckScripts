#!/usr/bin/env bash

set -euo pipefail

INSTALLER_DIR=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
		pwd -P
)
# shellcheck source=util/legacy-wrapper.bash
source "$INSTALLER_DIR/../util/legacy-wrapper.bash"

mgs_legacy_extract_game all "$@" || exit $?
mgs_legacy_replace_option --replace-ini --reset-ini

case "$MGS_LEGACY_GAME" in
	tpp)
		mgs_legacy_exec "$INSTALLER_DIR/mgsv-tpp/install-mgsv-tpp.bash"
		;;
	gz)
		mgs_legacy_exec "$INSTALLER_DIR/mgsv-gz/install-mgsv-gz.bash"
		;;
	all|"")
		mgs_legacy_warn "the per-game MGSVFix installers"
		printf '%s\n' \
			'error: the legacy multi-game MGSVFix command is ambiguous.' \
			'Run these per-game commands instead:' \
			'  ./installers/mgsv-tpp/install-mgsv-tpp.bash' \
			'  ./installers/mgsv-gz/install-mgsv-gz.bash' >&2
		exit 64
		;;
	*)
		printf 'error: unknown legacy game selection: %s\n' \
			"$MGS_LEGACY_GAME" >&2
		exit 64
		;;
esac
