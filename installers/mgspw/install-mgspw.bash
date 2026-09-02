#!/usr/bin/env bash

set -euo pipefail

INSTALLER_DIR=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
		pwd -P
)
# shellcheck source=util/installer-core.bash
source "$INSTALLER_DIR/../../util/installer-core.bash"
mgs_installer_init "${BASH_SOURCE[0]}"
# shellcheck source=util/mgspatriotfix-installer.bash
source "$MGS_UTIL_DIR/mgspatriotfix-installer.bash"

readonly MGS_GAME_NAME="Metal Gear Solid: Peace Walker"
readonly MGS_GAME_APPID=2492660
readonly MGS_GAME_MARKER="mgspw/METAL GEAR SOLID PEACE WALKER.exe"
readonly MGS_PATRIOTFIX_GAME_KEY=pw
readonly MGS_PATRIOTFIX_ASSET_MATCH='(^|[_-])PW([_.-]|$)|Peace.?Walker'
readonly MGS_PATRIOTFIX_ASSET_REJECT=MGS4

mgs_patriotfix_main "$@"
