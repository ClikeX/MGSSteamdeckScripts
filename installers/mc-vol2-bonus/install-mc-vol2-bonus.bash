#!/usr/bin/env bash

set -euo pipefail

INSTALLER_DIR=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
		pwd -P
)
# shellcheck source=util/installer-core.bash
source "$INSTALLER_DIR/../../util/installer-core.bash"
mgs_installer_init "${BASH_SOURCE[0]}"
# shellcheck source=util/mgsm2fix-installer.bash
source "$MGS_UTIL_DIR/mgsm2fix-installer.bash"

readonly MGS_GAME_NAME="Metal Gear Solid: Master Collection Vol. 2 Bonus Content"
readonly MGS_GAME_APPID=3036720
readonly MGS_GAME_MARKER="MGS MC2 Bonus Content.exe"

mgs_mgsm2fix_main "$@"
