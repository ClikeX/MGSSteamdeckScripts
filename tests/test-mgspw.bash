#!/usr/bin/env bash

set -u

ROOT=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
		pwd -P
)
source "$ROOT/tests/helpers/testlib.bash"
make_test_tmp

game="$TEST_TMP/MGS_PW"
payload="$TEST_TMP/payload"
archive="$TEST_TMP/PW_MGSPatriotFix.zip"
installer="$ROOT/installers/mgspw/install-mgspw.bash"
mkdir -p "$game/mgspw" "$payload/launcher/scripts" "$payload/mgspw/scripts"
printf 'game\n' > "$game/mgspw/METAL GEAR SOLID PEACE WALKER.exe"
printf 'original-loader\n' > "$game/mgspw/winmm.dll"
printf 'MZlauncher\n' > "$payload/launcher/d3d11.dll"
printf 'MZlauncher-plugin\n' > "$payload/launcher/scripts/MGSPatriotFix.asi"
printf 'MZtool\n' > "$payload/MGSPatriotFix Config Tool.exe"
printf 'MZgame-plugin\n' > "$payload/mgspw/scripts/MGSPatriotFix.asi"
printf 'MZloader\n' > "$payload/mgspw/winmm.dll"
(cd "$payload" && zip -qr "$archive" .)

output=$("$installer" --path "$game" --zip "$archive")
game=$(
	cd -- "$game" &&
		pwd -P
)
assert_file_exists "$game/mgspw/scripts/MGSPatriotFix.asi" \
	"Peace Walker installs MGSPatriotFix plugin"
assert_file_exists "$game/MGSPatriotFix Config Tool.exe" \
	"Peace Walker installs the configuration tool"
assert_contains "$output" "$game/MGSPatriotFix Config Tool.exe" \
	"Peace Walker reports the configuration tool"
assert_contains "$output" "Protontricks" \
	"Peace Walker reports the configuration tool dependency"

"$installer" --path "$game" --write-settings >/dev/null
assert_file_exists "$game/MGSPatriotFix.settings" \
	"Peace Walker writes default settings"
assert_contains "$(cat "$game/MGSPatriotFix.settings")" \
	"Button Icons (PW) = Keyboard" \
	"Peace Walker settings use game-specific defaults"

printf 'custom-settings\n' > "$game/MGSPatriotFix.settings"
set +e
"$installer" --path "$game" --write-settings >/dev/null 2>&1
status=$?
set -e
assert_status 1 "$status" "Peace Walker refuses to replace settings by default"
assert_eq "custom-settings" "$(cat "$game/MGSPatriotFix.settings")" \
	"Peace Walker preserves existing settings"

"$installer" --path "$game" --write-settings --yes >/dev/null
assert_contains "$(cat "$game/MGSPatriotFix.settings")" \
	"Button Icons (PW) = Keyboard" \
	"Peace Walker replaces settings with explicit confirmation"

for mode in --list --uninstall --set-launch-options; do
	set +e
	"$installer" --path "$game" --write-settings "$mode" >/dev/null 2>&1
	status=$?
	set -e
	assert_status 64 "$status" \
		"Peace Walker write settings conflicts with $mode"
done

printf 'custom-settings\n' > "$game/MGSPatriotFix.settings"
"$installer" --path "$game" --uninstall >/dev/null
assert_eq "original-loader" "$(cat "$game/mgspw/winmm.dll")" \
	"Peace Walker uninstall restores original loader"
assert_eq "custom-settings" "$(cat "$game/MGSPatriotFix.settings")" \
	"Peace Walker uninstall preserves settings"
[[ ! -e "$game/mgspw/scripts/MGSPatriotFix.asi" ]] ||
	test_fail "Peace Walker plugin survived uninstall"
test_pass "Peace Walker uninstall removes tracked plugin"
