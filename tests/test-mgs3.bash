#!/usr/bin/env bash

set -u

ROOT=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
		pwd -P
)
source "$ROOT/tests/helpers/testlib.bash"
make_test_tmp

hdfix_payload="$TEST_TMP/hdfix"
crouch_payload="$TEST_TMP/crouch"
qcamo_payload="$TEST_TMP/qcamo"
hdfix_archive="$TEST_TMP/MGSHDFix.zip"
crouch_archive="$TEST_TMP/MGS3CrouchWalk.zip"
qcamo_archive="$TEST_TMP/qcamo.zip"
installer="$ROOT/installers/mgs3/install-mgs3.bash"
mkdir -p "$hdfix_payload/plugins" "$crouch_payload/assets/mtar/us" "$qcamo_payload"
printf 'MZtool\n' > "$hdfix_payload/plugins/MGSHDFix Config Tool.exe"
printf 'MZhdfix\n' > "$hdfix_payload/plugins/MGSHDFix.asi"
printf 'MZhttp\n' > "$hdfix_payload/winhttp.dll"
printf 'MZinet\n' > "$hdfix_payload/wininet.dll"
printf 'duplicate-loader\n' > "$crouch_payload/d3d11.dll"
printf 'MZcrouch\n' > "$crouch_payload/MGS3CrouchWalk.asi"
printf 'speed=1\n' > "$crouch_payload/MGS3CrouchWalk.ini"
printf 'mod-animation\n' > "$crouch_payload/assets/mtar/us/006891cc.mtar"
printf 'MZqcamo\n' > "$qcamo_payload/qcamo.asi"
(cd "$hdfix_payload" && zip -qr "$hdfix_archive" .)
(cd "$crouch_payload" && zip -qr "$crouch_archive" .)
(cd "$qcamo_payload" && zip -qr "$qcamo_archive" .)

game="$TEST_TMP/MGS3"
mkdir -p "$game/assets/mtar/us"
printf 'game\n' > "$game/METAL GEAR SOLID3.exe"
printf 'original-loader\n' > "$game/wininet.dll"
printf 'original-animation\n' > "$game/assets/mtar/us/006891cc.mtar"
printf 'original-qcamo\n' > "$game/qcamo.asi"

"$installer" --path "$game" --zip "$hdfix_archive" \
	--crouchwalk-zip "$crouch_archive" >/dev/null
assert_file_exists "$game/plugins/MGSHDFix.asi" \
	"MGS3 installs MGSHDFix"
assert_file_exists "$game/MGS3CrouchWalk.asi" \
	"MGS3 installs CrouchWalk by default"
assert_eq "original-qcamo" "$(cat "$game/qcamo.asi")" \
	"MGS3 does not install qcamo unless selected"
assert_eq "speed=1" "$(cat "$game/MGS3CrouchWalk.ini")" \
	"MGS3 creates the CrouchWalk INI"
[[ ! -e "$game/d3d11.dll" ]] ||
	test_fail "MGS3 installed CrouchWalk's duplicate loader"
test_pass "MGS3 excludes CrouchWalk duplicate loader"
assert_file_exists "$game/.mgs-installer/mgshdfix/files.txt" \
	"MGS3 tracks MGSHDFix separately"
assert_file_exists "$game/.mgs-installer/mgs3crouchwalk/files.txt" \
	"MGS3 tracks CrouchWalk separately"
[[ ! -e "$game/.mgs-installer/mgs3qcamo/files.txt" ]] ||
	test_fail "MGS3 tracked qcamo without selecting it"
test_pass "MGS3 leaves qcamo untracked unless selected"

printf 'speed=custom\n' > "$game/MGS3CrouchWalk.ini"
"$installer" --path "$game" --zip "$hdfix_archive" \
	--crouchwalk-zip "$crouch_archive" >/dev/null
assert_eq "speed=custom" "$(cat "$game/MGS3CrouchWalk.ini")" \
	"MGS3 preserves edited CrouchWalk INI"
assert_eq "speed=1" "$(cat "$game/MGS3CrouchWalk.ini.new")" \
	"MGS3 writes changed CrouchWalk defaults"

"$installer" --path "$game" --zip "$hdfix_archive" \
	--crouchwalk-zip "$crouch_archive" --reset-ini >/dev/null
assert_eq "speed=1" "$(cat "$game/MGS3CrouchWalk.ini")" \
	"MGS3 resets the CrouchWalk INI"

"$installer" --path "$game" --zip "$hdfix_archive" \
	--crouchwalk-zip "$crouch_archive" --qcamo-zip "$qcamo_archive" >/dev/null
assert_eq "MZqcamo" "$(cat "$game/qcamo.asi")" \
	"MGS3 installs qcamo when selected"
assert_file_exists "$game/.mgs-installer/mgs3qcamo/files.txt" \
	"MGS3 tracks qcamo separately"

hdfix_only="$TEST_TMP/MGS3-hdfix-only"
mkdir -p "$hdfix_only"
printf 'game\n' > "$hdfix_only/METAL GEAR SOLID3.exe"
"$installer" --path "$hdfix_only" --zip "$hdfix_archive" \
	--no-crouchwalk >/dev/null
assert_file_exists "$hdfix_only/plugins/MGSHDFix.asi" \
	"MGS3 supports MGSHDFix-only install"
[[ ! -e "$hdfix_only/MGS3CrouchWalk.asi" ]] ||
	test_fail "MGSHDFix-only install added CrouchWalk"
test_pass "MGS3 no-crouchwalk omits CrouchWalk"

set +e
"$installer" --path "$hdfix_only" --zip "$hdfix_archive" \
	--no-crouchwalk --reset-ini >/dev/null 2>&1
status=$?
set -e
assert_status 64 "$status" "MGS3 rejects reset INI without CrouchWalk"

set +e
"$installer" --path "$hdfix_only" --zip "$hdfix_archive" \
	--qcamo-zip "$qcamo_archive" --qcamo-version v1.0.0 >/dev/null 2>&1
status=$?
set -e
assert_status 64 "$status" "MGS3 rejects conflicting qcamo sources"

"$installer" --path "$game" --uninstall >/dev/null
assert_eq "original-loader" "$(cat "$game/wininet.dll")" \
	"MGS3 uninstall restores original loader"
assert_eq "original-animation" \
	"$(cat "$game/assets/mtar/us/006891cc.mtar")" \
	"MGS3 uninstall restores localized animation"
assert_eq "original-qcamo" "$(cat "$game/qcamo.asi")" \
	"MGS3 uninstall restores preexisting qcamo file"
[[ ! -e "$game/MGS3CrouchWalk.asi" ]] ||
	test_fail "CrouchWalk survived MGS3 uninstall"
test_pass "MGS3 uninstall removes CrouchWalk first"

legacy="$TEST_TMP/MGS3-legacy"
mkdir -p "$legacy/assets/mtar/us" "$legacy/.mgshdfix-backup/assets/mtar/us"
printf 'game\n' > "$legacy/METAL GEAR SOLID3.exe"
printf 'mod-loader\n' > "$legacy/wininet.dll"
printf 'mod-animation\n' > "$legacy/assets/mtar/us/006891cc.mtar"
printf 'original-loader\n' > "$legacy/.mgshdfix-backup/wininet.dll"
printf 'original-animation\n' \
	> "$legacy/.mgshdfix-backup/assets/mtar/us/006891cc.mtar"
printf 'wininet.dll\n' > "$legacy/.mgshdfix-files.txt"
printf 'assets/mtar/us/006891cc.mtar\n' \
	> "$legacy/.mgs3crouchwalk-files.txt"
"$installer" --path "$legacy" --uninstall >/dev/null
assert_eq "original-loader" "$(cat "$legacy/wininet.dll")" \
	"MGS3 restores legacy MGSHDFix backup"
assert_eq "original-animation" \
	"$(cat "$legacy/assets/mtar/us/006891cc.mtar")" \
	"MGS3 restores legacy shared CrouchWalk backup"
