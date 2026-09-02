#!/usr/bin/env bash

set -u

ROOT=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
		pwd -P
)
source "$ROOT/tests/helpers/testlib.bash"
make_test_tmp

game="$TEST_TMP/MGS1"
payload="$TEST_TMP/payload"
archive="$TEST_TMP/MGSM2Fix.zip"
mkdir -p "$game" "$payload/plugins"
printf 'game\n' > "$game/METAL GEAR SOLID.exe"
printf 'original-loader\n' > "$game/dinput8.dll"
printf 'MZplugin\n' > "$payload/plugins/MGSM2Fix.asi"
printf 'MZloader\n' > "$payload/dinput8.dll"
printf 'stock=true\n' > "$payload/MGSM2Fix.ini"
(cd "$payload" && zip -qr "$archive" .)

"$ROOT/installers/mgs1/install-mgs1.bash" --path "$game" --zip "$archive" >/dev/null
assert_file_exists "$game/plugins/MGSM2Fix.asi" "MGS1 installs MGSM2Fix plugin"
assert_eq "stock=true" "$(cat "$game/MGSM2Fix.ini")" "MGS1 creates missing INI"

printf 'user=true\n' > "$game/MGSM2Fix.ini"
"$ROOT/installers/mgs1/install-mgs1.bash" --path "$game" --zip "$archive" >/dev/null
assert_eq "user=true" "$(cat "$game/MGSM2Fix.ini")" "MGS1 preserves edited INI"
assert_eq "stock=true" "$(cat "$game/MGSM2Fix.ini.new")" "MGS1 writes new defaults"

"$ROOT/installers/mgs1/install-mgs1.bash" --path "$game" --zip "$archive" \
	--reset-ini >/dev/null
assert_eq "stock=true" "$(cat "$game/MGSM2Fix.ini")" "MGS1 resets INI on request"

dry_game="$TEST_TMP/dry-game"
mkdir -p "$dry_game"
printf 'game\n' > "$dry_game/METAL GEAR SOLID.exe"
"$ROOT/installers/mgs1/install-mgs1.bash" --path "$dry_game" --zip "$archive" \
	--dry-run >/dev/null
[[ ! -e "$dry_game/plugins/MGSM2Fix.asi" ]] || test_fail "MGS1 dry-run wrote files"
test_pass "MGS1 dry-run is read-only"

"$ROOT/installers/mgs1/install-mgs1.bash" --path "$game" --uninstall >/dev/null
assert_eq "original-loader" "$(cat "$game/dinput8.dll")" \
	"MGS1 uninstall restores original loader"
[[ ! -e "$game/plugins/MGSM2Fix.asi" ]] || test_fail "MGS1 plugin survived uninstall"
test_pass "MGS1 uninstall removes tracked plugin"
