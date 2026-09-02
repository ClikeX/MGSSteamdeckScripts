#!/usr/bin/env bash

set -euo pipefail

INSTALLER_DIR=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
		pwd -P
)
# shellcheck source=util/legacy-wrapper.bash
source "$INSTALLER_DIR/../util/legacy-wrapper.bash"

mgs_legacy_extract_game mgs1 "$@" || exit $?
mgs_legacy_replace_option --replace-ini --reset-ini

case "$MGS_LEGACY_GAME" in
	mgs1)
		mgs_legacy_exec "$INSTALLER_DIR/mgs1/install-mgs1.bash"
		;;
	bonus1)
		mgs_legacy_exec \
			"$INSTALLER_DIR/mc-vol1-bonus/install-mc-vol1-bonus.bash"
		;;
	bonus2)
		mgs_legacy_exec \
			"$INSTALLER_DIR/mc-vol2-bonus/install-mc-vol2-bonus.bash"
		;;
	mgs4)
		if mgs_legacy_has_option --uninstall; then
			mgs_legacy_warn "$INSTALLER_DIR/mgs4/install-mgs4.bash"
			printf '%s\n' \
				'error: the new MGS4 --uninstall removes every tracked MGS4 component.' \
				'Review installed state with:' \
				'  ./installers/mgs4/install-mgs4.bash --list' \
				'Then use the per-game installer directly if all-component uninstall is intended.' >&2
			exit 64
		fi
		if mgs_legacy_has_exclusive_mode; then
			mgs_legacy_exec "$INSTALLER_DIR/mgs4/install-mgs4.bash"
		fi
		for option in "${MGS_LEGACY_ARGS[@]}"; do
			case "$option" in
				-v|--version|--version=*)
					printf '%s\n' \
						'error: a legacy MGS4 MGSM2Fix version pin cannot be translated.' \
						'Use the MGS4 installer with --mgs1-flashback or --mgs1-flashback-zip.' >&2
					exit 64
					;;
			esac
		done
		mgs_legacy_replace_option --zip --mgs1-flashback-zip
		mgs_legacy_exec "$INSTALLER_DIR/mgs4/install-mgs4.bash" \
			--mgs1-flashback
		;;
	all|*,*)
		mgs_legacy_warn "the applicable per-game MGSM2Fix installers"
		printf '%s\n' \
			'error: the legacy multi-game MGSM2Fix command is ambiguous.' \
			'Run the applicable per-game commands instead:' \
			'  ./installers/mgs1/install-mgs1.bash' \
			'  ./installers/mc-vol1-bonus/install-mc-vol1-bonus.bash' \
			'  ./installers/mc-vol2-bonus/install-mc-vol2-bonus.bash' \
			'  ./installers/mgs4/install-mgs4.bash --mgs1-flashback' >&2
		exit 64
		;;
	*)
		printf 'error: unknown legacy game selection: %s\n' \
			"$MGS_LEGACY_GAME" >&2
		exit 64
		;;
esac
