#!/usr/bin/env bash

set -u

ROOT=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
		pwd -P
)
source "$ROOT/tests/helpers/testlib.bash"
make_test_tmp

game="$TEST_TMP/MGS2"
payload="$TEST_TMP/payload"
archive="$TEST_TMP/MGSHDFix.zip"
installer="$ROOT/installers/mgs2/install-mgs2.bash"
mkdir -p "$game" "$payload/logs" "$payload/plugins"
printf 'game\n' > "$game/METAL GEAR SOLID2.exe"
printf 'original-loader\n' > "$game/wininet.dll"
printf 'log\n' > "$payload/logs/MGSHDFix_Game.log"
printf 'MZtool\n' > "$payload/plugins/MGSHDFix Config Tool.exe"
printf 'MZplugin\n' > "$payload/plugins/MGSHDFix.asi"
printf 'MZhttp\n' > "$payload/winhttp.dll"
printf 'MZinet\n' > "$payload/wininet.dll"
(cd "$payload" && zip -qr "$archive" .)

output=$("$installer" --path "$game" --zip "$archive")
game=$(
	cd -- "$game" &&
		pwd -P
)
assert_file_exists "$game/plugins/MGSHDFix.asi" \
	"MGS2 installs MGSHDFix plugin"
assert_file_exists "$game/plugins/MGSHDFix Config Tool.exe" \
	"MGS2 installs the configuration tool"
[[ ! -e "$game/logs/MGSHDFix_Game.log" ]] ||
	test_fail "MGS2 installed excluded release logs"
test_pass "MGS2 excludes release logs"
assert_eq "MZinet" "$(cat "$game/wininet.dll")" \
	"MGS2 installs the current loader"
assert_contains "$output" "$game/plugins/MGSHDFix Config Tool.exe" \
	"MGS2 reports the discovered configuration tool"
assert_contains "$output" "Default / Original" \
	"MGS2 reports launcher resolution guidance"
assert_contains "$output" "Protontricks" \
	"MGS2 reports the configuration tool dependency"

printf 'user-settings\n' > "$game/plugins/MGSHDFix.settings"
printf 'legacy\n' > "$game/d3d11.dll"
printf 'legacy\n' > "$game/MGSHDFix.asi"
printf '%s\n' \
	plugins/MGSHDFix.asi \
	"plugins/MGSHDFix Config Tool.exe" \
	winhttp.dll \
	wininet.dll \
	d3d11.dll \
	MGSHDFix.asi \
	> "$game/.mgs-installer/mgshdfix/files.txt"

"$installer" --path "$game" --zip "$archive" >/dev/null
assert_eq "user-settings" "$(cat "$game/plugins/MGSHDFix.settings")" \
	"MGS2 preserves generated settings"
[[ ! -e "$game/d3d11.dll" && ! -e "$game/MGSHDFix.asi" ]] ||
	test_fail "MGS2 retained tracked stale files"
test_pass "MGS2 removes tracked stale files"

set +e
"$installer" --path "$game" --zip "$archive" --reset-ini >/dev/null 2>&1
status=$?
set -e
assert_status 64 "$status" "MGS2 rejects reset INI"

"$installer" --path "$game" --uninstall >/dev/null
assert_eq "original-loader" "$(cat "$game/wininet.dll")" \
	"MGS2 uninstall restores original loader"
assert_eq "user-settings" "$(cat "$game/plugins/MGSHDFix.settings")" \
	"MGS2 uninstall preserves generated settings"
[[ ! -e "$game/plugins/MGSHDFix.asi" ]] ||
	test_fail "MGS2 plugin survived uninstall"
test_pass "MGS2 uninstall removes tracked plugin"
