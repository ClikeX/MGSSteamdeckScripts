#!/usr/bin/env bash

set -u

ROOT=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
		pwd -P
)
source "$ROOT/tests/helpers/testlib.bash"
source "$ROOT/util/install-state.bash"
make_test_tmp

target="$TEST_TMP/game"
mkdir -p "$target/plugins"
printf 'mod\n' > "$target/plugins/mod.asi"
manifest_source="$TEST_TMP/manifest"
printf 'plugins/mod.asi\n' > "$manifest_source"
mgs_state_write_manifest "$target" mgshdfix "$manifest_source"
assert_file_exists "$target/.mgs-installer/mgshdfix/files.txt" "current manifest is written"

owned=$(mgs_state_owned_files "$target" mgshdfix)
assert_eq "plugins/mod.asi" "$owned" "current ownership is read"

printf 'original\n' > "$target/plugins/mod.asi"
mgs_state_backup_file "$target" mgshdfix plugins/mod.asi
printf 'changed\n' > "$target/plugins/mod.asi"
mgs_state_uninstall "$target" mgshdfix
assert_eq "original" "$(cat "$target/plugins/mod.asi")" "uninstall restores current backup"

legacy_target="$TEST_TMP/legacy"
mkdir -p "$legacy_target/.mgsm2fix-backup"
printf 'MGSM2Fix.asi\n' > "$legacy_target/.mgsm2fix-files.txt"
printf 'mod\n' > "$legacy_target/MGSM2Fix.asi"
printf 'game\n' > "$legacy_target/.mgsm2fix-backup/MGSM2Fix.asi"
assert_eq "MGSM2Fix.asi" "$(mgs_state_owned_files "$legacy_target" mgsm2fix)" \
	"legacy manifest ownership is read"
mgs_state_uninstall "$legacy_target" mgsm2fix
assert_eq "game" "$(cat "$legacy_target/MGSM2Fix.asi")" \
	"direct legacy uninstall restores its backup"

shared="$TEST_TMP/shared"
mkdir -p "$shared/.mgshdfix-backup/assets"
printf 'assets/animation.bin\n' > "$shared/.mgs3crouchwalk-files.txt"
printf 'modded\n' > "$shared/assets-file"
printf 'original\n' > "$shared/.mgshdfix-backup/assets/animation.bin"
backup=$(mgs_state_find_backup "$shared" mgs3crouchwalk assets/animation.bin)
assert_eq "$shared/.mgshdfix-backup/assets/animation.bin" "$backup" \
	"CrouchWalk finds the shared legacy backup"

set +e
mgs_state_uninstall "$TEST_TMP/none" mgsvfix >/dev/null 2>&1
status=$?
set -e
assert_status 3 "$status" "uninstall reports missing component state"
