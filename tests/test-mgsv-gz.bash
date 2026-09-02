#!/usr/bin/env bash

set -u

ROOT=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
		pwd -P
)
source "$ROOT/tests/helpers/testlib.bash"
make_test_tmp

game="$TEST_TMP/MGS_GZ"
payload="$TEST_TMP/payload"
archive="$TEST_TMP/MGSVFix.zip"
installer="$ROOT/installers/mgsv-gz/install-mgsv-gz.bash"
mkdir -p "$game" "$payload"
printf 'game\n' > "$game/MgsGroundZeroes.exe"
printf 'original-loader\n' > "$game/winmm.dll"
printf 'MZplugin\n' > "$payload/MGSVFix.asi"
printf 'stock=true\n' > "$payload/MGSVFix.ini"
printf 'MZloader\n' > "$payload/winmm.dll"
(cd "$payload" && zip -qr "$archive" .)

"$installer" --path "$game" --zip "$archive" >/dev/null
assert_file_exists "$game/MGSVFix.asi" \
	"Ground Zeroes installs MGSVFix plugin"
assert_eq "stock=true" "$(cat "$game/MGSVFix.ini")" \
	"Ground Zeroes creates missing INI"
assert_eq "MZloader" "$(cat "$game/winmm.dll")" \
	"Ground Zeroes installs the current loader"

printf 'user=true\n' > "$game/MGSVFix.ini"
"$installer" --path "$game" --zip "$archive" >/dev/null
assert_eq "user=true" "$(cat "$game/MGSVFix.ini")" \
	"Ground Zeroes preserves edited INI"
assert_eq "stock=true" "$(cat "$game/MGSVFix.ini.new")" \
	"Ground Zeroes writes new defaults"

printf 'legacy\n' > "$game/dinput8.dll"
printf 'legacy\n' > "$game/MGSVFix.asi"
printf '%s\n' MGSVFix.asi MGSVFix.ini MGSVFix.ini.new winmm.dll dinput8.dll \
	> "$game/.mgs-installer/mgsvfix/files.txt"
"$installer" --path "$game" --zip "$archive" >/dev/null
[[ ! -e "$game/dinput8.dll" ]] ||
	test_fail "Ground Zeroes retained a tracked stale loader"
test_pass "Ground Zeroes removes tracked stale loader"

"$installer" --path "$game" --zip "$archive" --reset-ini >/dev/null
assert_eq "stock=true" "$(cat "$game/MGSVFix.ini")" \
	"Ground Zeroes resets INI on request"

for option in --ih --ih-restore --ih-zip; do
	set +e
	if [[ $option == --ih-zip ]]; then
		"$installer" --path "$game" "$option" package.zip >/dev/null 2>&1
	else
		"$installer" --path "$game" "$option" >/dev/null 2>&1
	fi
	status=$?
	set -e
	assert_status 64 "$status" "Ground Zeroes rejects $option"
done

"$installer" --path "$game" --uninstall >/dev/null
assert_eq "original-loader" "$(cat "$game/winmm.dll")" \
	"Ground Zeroes uninstall restores original loader"
[[ ! -e "$game/MGSVFix.asi" ]] ||
	test_fail "Ground Zeroes plugin survived uninstall"
test_pass "Ground Zeroes uninstall removes tracked plugin"
