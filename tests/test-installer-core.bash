#!/usr/bin/env bash

set -u

ROOT=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
		pwd -P
)
source "$ROOT/tests/helpers/testlib.bash"
source "$ROOT/util/installer-core.bash"
make_test_tmp

fake_installer="$ROOT/installers/mgs1/install-mgs1.bash"
mgs_installer_init "$fake_installer"
assert_eq "$ROOT" "$MGS_REPO_ROOT" "installer core resolves repository root"

mgs_installer_create_workspace core-test
workspace=$MGS_WORK_DIR
[[ -d $workspace ]] || test_fail "workspace was not created"
test_pass "workspace is created"
mgs_installer_cleanup
[[ ! -e $workspace ]] || test_fail "workspace was not removed"
test_pass "workspace is removed"

game="$TEST_TMP/game"
mkdir -p "$game"
printf 'exe\n' > "$game/METAL GEAR SOLID.exe"
mgs_cli_reset
MGS_CLI_PATH=$game
resolved=$(mgs_installer_resolve_target 2131630 "METAL GEAR SOLID.exe")
resolved_expected=$(cd -- "$game" && pwd -P)
assert_eq "$resolved_expected" "$resolved" "explicit game path is resolved"

rm "$game/METAL GEAR SOLID.exe"
set +e
mgs_installer_resolve_target 2131630 "METAL GEAR SOLID.exe" >/dev/null 2>&1
status=$?
set -e
assert_status 1 "$status" "missing marker is rejected"
