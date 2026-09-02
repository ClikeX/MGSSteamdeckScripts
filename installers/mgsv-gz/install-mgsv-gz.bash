#!/usr/bin/env bash

set -euo pipefail

INSTALLER_DIR=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
		pwd -P
)
# shellcheck source=util/installer-core.bash
source "$INSTALLER_DIR/../../util/installer-core.bash"
mgs_installer_init "${BASH_SOURCE[0]}"
# shellcheck source=util/mgsvfix-installer.bash
source "$MGS_UTIL_DIR/mgsvfix-installer.bash"

readonly MGS_GAME_NAME="Metal Gear Solid V: Ground Zeroes"
readonly MGS_GAME_APPID=311340
readonly MGS_GAME_MARKER="MgsGroundZeroes.exe"

mgs_mgsvfix_main "$@"
