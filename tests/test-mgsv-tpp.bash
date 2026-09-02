#!/usr/bin/env bash

set -u

ROOT=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
		pwd -P
)
source "$ROOT/tests/helpers/testlib.bash"
make_test_tmp

game="$TEST_TMP/MGS_TPP"
payload="$TEST_TMP/mgsvfix"
archive="$TEST_TMP/MGSVFix.zip"
installer="$ROOT/installers/mgsv-tpp/install-mgsv-tpp.bash"
mkdir -p "$game/master/0" "$payload"
printf 'game\n' > "$game/mgsvtpp.exe"
printf 'original-loader\n' > "$game/winmm.dll"
printf 'vanilla-00\n' > "$game/master/0/00.dat"
printf 'vanilla-01\n' > "$game/master/0/01.dat"
printf 'MZplugin\n' > "$payload/MGSVFix.asi"
printf 'stock=true\n' > "$payload/MGSVFix.ini"
printf 'MZloader\n' > "$payload/winmm.dll"
(cd "$payload" && zip -qr "$archive" .)

"$installer" --path "$game" --zip "$archive" >/dev/null
assert_file_exists "$game/MGSVFix.asi" "TPP installs MGSVFix"
assert_eq "stock=true" "$(cat "$game/MGSVFix.ini")" \
	"TPP creates missing MGSVFix INI"

printf 'user=true\n' > "$game/MGSVFix.ini"
"$installer" --path "$game" --zip "$archive" >/dev/null
assert_eq "user=true" "$(cat "$game/MGSVFix.ini")" \
	"TPP preserves edited MGSVFix INI"
assert_eq "stock=true" "$(cat "$game/MGSVFix.ini.new")" \
	"TPP writes changed MGSVFix defaults"

fake_home="$TEST_TMP/home"
save="$fake_home/.steam/steam/userdata/111/287700"
mkdir -p "$save" "$fake_home/.steam/steam/steamapps"
printf 'save\n' > "$save/save.dat"
HOME="$fake_home" "$installer" --path "$game" --ih >/dev/null
assert_eq "vanilla-00" "$(cat "$game/.mgsv-ih-backup/00.dat")" \
	"TPP backs up vanilla 00.dat"
assert_eq "vanilla-01" "$(cat "$game/.mgsv-ih-backup/01.dat")" \
	"TPP backs up vanilla 01.dat"
save_backup=$(find "$game/.mgsv-ih-backup" -type f -name save.dat -print -quit)
assert_file_exists "$save_backup" "TPP creates timestamped save backup"

printf 'possibly-modded\n' > "$game/master/0/00.dat"
HOME="$fake_home" "$installer" --path "$game" --ih >/dev/null 2>&1
assert_eq "vanilla-00" "$(cat "$game/.mgsv-ih-backup/00.dat")" \
	"TPP never overwrites presumed-vanilla backup"

external="$TEST_TMP/external"
external_game="$TEST_TMP/MGS_TPP-external"
mkdir -p "$external" "$external_game/master/0"
printf 'game\n' > "$external_game/mgsvtpp.exe"
printf 'external-00\n' > "$external_game/master/0/00.dat"
printf 'external-01\n' > "$external_game/master/0/01.dat"
HOME="$fake_home" "$installer" --path "$external_game" --ih \
	--ih-backup-dir "$external" >/dev/null 2>&1
assert_eq "external-00" "$(cat "$external/mgsv-ih-backup/00.dat")" \
	"TPP supports an external archive backup directory"

ih_payload="$TEST_TMP/ih-payload"
ih_zip="$TEST_TMP/InfiniteHeaven.zip"
empty_payload="$TEST_TMP/no-package"
empty_zip="$TEST_TMP/IH-docs.zip"
mkdir -p "$ih_payload/package" "$empty_payload"
printf 'package\n' > "$ih_payload/package/InfiniteHeaven.mgsv"
printf 'readme\n' > "$empty_payload/README.txt"
(cd "$ih_payload" && zip -qr "$ih_zip" .)
(cd "$empty_payload" && zip -qr "$empty_zip" .)
stage_output=$("$installer" --path "$game" --ih-zip "$ih_zip" 2>&1)
assert_file_exists \
	"$game/InfiniteHeaven-staging/InfiniteHeaven/package/InfiniteHeaven.mgsv" \
	"TPP stages an Infinite Heaven package"
assert_contains "$stage_output" "InfiniteHeaven.mgsv" \
	"TPP reports staged MGSV packages"
stage_output=$("$installer" --path "$game" --ih-zip "$empty_zip" 2>&1)
assert_contains "$stage_output" "no .mgsv package" \
	"TPP warns when a staged ZIP has no MGSV package"

printf 'modded-00\n' > "$game/master/0/00.dat"
printf 'modded-01\n' > "$game/master/0/01.dat"
mkdir -p "$game/mod/saves"
printf 'settings\n' > "$game/mod/saves/ih_save.lua"
printf 'snakebite\n' > "$game/Snakebite.xml"
"$installer" --path "$game" --ih-restore >/dev/null
assert_eq "vanilla-00" "$(cat "$game/master/0/00.dat")" \
	"TPP restore reinstates vanilla 00.dat"
assert_eq "vanilla-01" "$(cat "$game/master/0/01.dat")" \
	"TPP restore reinstates vanilla 01.dat"
[[ ! -e "$game/mod" ]] || test_fail "TPP restore retained mod directory"
test_pass "TPP restore removes mod directory"
ih_save_backup=$(find "$game/.mgsv-ih-backup" -type f \
	-name ih_save.lua -print -quit)
assert_file_exists "$ih_save_backup" "TPP restore preserves IH settings"
[[ ! -e "$game/Snakebite.xml" ]] ||
	test_fail "TPP restore retained Snakebite.xml"
test_pass "TPP restore removes Snakebite state file"

no_backup="$TEST_TMP/MGS_TPP-no-backup"
mkdir -p "$no_backup/master/0"
printf 'game\n' > "$no_backup/mgsvtpp.exe"
set +e
"$installer" --path "$no_backup" --ih-restore >/dev/null 2>&1
status=$?
set -e
assert_status 1 "$status" "TPP restore requires a vanilla archive backup"

for args in \
	"--ih --list" \
	"--ih --uninstall" \
	"--ih --set-launch-options" \
	"--ih-restore --ih" \
	"--ih-restore --ih-zip $ih_zip" \
	"--ih-restore --ih-backup-dir $external"; do
	set +e
	# shellcheck disable=SC2086
	"$installer" --path "$game" $args >/dev/null 2>&1
	status=$?
	set -e
	assert_status 64 "$status" "TPP rejects conflicting modes: $args"
done

"$installer" --path "$game" --uninstall >/dev/null
assert_eq "original-loader" "$(cat "$game/winmm.dll")" \
	"TPP uninstall restores original MGSVFix loader"
assert_file_exists "$game/.mgsv-ih-backup/00.dat" \
	"TPP MGSVFix uninstall preserves Infinite Heaven backup"
