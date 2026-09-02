#!/usr/bin/env bash

set -u

ROOT=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
		pwd -P
)
source "$ROOT/tests/helpers/testlib.bash"
make_test_tmp

game="$TEST_TMP/MGS4"
patriot="$TEST_TMP/patriot"
flashback="$TEST_TMP/flashback"
patriot_zip="$TEST_TMP/MGS4_MGSPatriotFix.zip"
flashback_zip="$TEST_TMP/MGSM2Fix.zip"
modloader="$TEST_TMP/MGS4ModLoader.asi"
installer="$ROOT/installers/mgs4/install-mgs4.bash"

mkdir -p "$game/MGS4/scripts" "$game/MGS4/mods" "$patriot/MGS4/scripts" \
	"$patriot/Launcher/scripts" "$flashback/plugins"
printf 'game\n' > "$game/MGS4/mgs4.exe"
printf 'flashback\n' > "$game/MGS4/mgs1.exe"
printf 'original-patriot-loader\n' > "$game/MGS4/winmm.dll"
printf 'original-modloader\n' > "$game/MGS4/scripts/MGS4ModLoader.asi"
printf 'user-mod\n' > "$game/MGS4/mods/user-mod.txt"

printf 'MZpatriot\n' > "$patriot/MGS4/scripts/MGSPatriotFix.asi"
printf 'MZlauncher\n' > "$patriot/Launcher/scripts/MGSPatriotFix.asi"
printf 'MZgame-loader\n' > "$patriot/MGS4/winmm.dll"
printf 'MZlauncher-loader\n' > "$patriot/Launcher/d3d11.dll"
printf 'MZtool\n' > "$patriot/MGSPatriotFix Config Tool.exe"
(cd "$patriot" && zip -qr "$patriot_zip" .)

printf 'MZflashback\n' > "$flashback/plugins/MGSM2Fix.asi"
printf 'MZflashback-loader\n' > "$flashback/dinput8.dll"
printf 'flashback-default=true\n' > "$flashback/MGSM2Fix.ini"
(cd "$flashback" && zip -qr "$flashback_zip" .)
printf 'MZmodloader\n' > "$modloader"

patriot_only="$TEST_TMP/MGS4-patriot-only"
mkdir -p "$patriot_only/MGS4"
printf 'game\n' > "$patriot_only/MGS4/mgs4.exe"
"$installer" --path "$patriot_only" --zip "$patriot_zip" >/dev/null
assert_file_exists "$patriot_only/MGS4/scripts/MGSPatriotFix.asi" \
	"MGS4 supports PatriotFix-only install"
[[ ! -e "$patriot_only/MGS4/plugins/MGSM2Fix.asi" ]] ||
	test_fail "PatriotFix-only install added flashback MGSM2Fix"
[[ ! -e "$patriot_only/MGS4/scripts/MGS4ModLoader.asi" ]] ||
	test_fail "PatriotFix-only install added Mod Loader"
test_pass "MGS4 PatriotFix-only install omits optional components"

"$installer" --path "$game" --zip "$patriot_zip" \
	--mgs1-flashback-zip "$flashback_zip" \
	--modloader-file "$modloader" >/dev/null
assert_file_exists "$game/MGS4/scripts/MGSPatriotFix.asi" \
	"MGS4 installs PatriotFix"
assert_file_exists "$game/MGS4/plugins/MGSM2Fix.asi" \
	"MGS4 installs flashback MGSM2Fix beside mgs1.exe"
assert_eq "MZmodloader" \
	"$(cat "$game/MGS4/scripts/MGS4ModLoader.asi")" \
	"MGS4 installs Mod Loader"
assert_file_exists "$game/MGS4/scripts/MGS4ModLoader.ini" \
	"MGS4 creates missing Mod Loader INI"
assert_file_exists "$game/MGS4/mods/user-mod.txt" \
	"MGS4 preserves existing user mods during install"

printf 'flashback-user=true\n' > "$game/MGS4/MGSM2Fix.ini"
printf 'Enabled = custom\n' > "$game/MGS4/scripts/MGS4ModLoader.ini"
"$installer" --path "$game" --zip "$patriot_zip" \
	--mgs1-flashback-zip "$flashback_zip" \
	--modloader-file "$modloader" >/dev/null
assert_eq "flashback-user=true" "$(cat "$game/MGS4/MGSM2Fix.ini")" \
	"MGS4 preserves edited flashback INI"
assert_eq "Enabled = custom" \
	"$(cat "$game/MGS4/scripts/MGS4ModLoader.ini")" \
	"MGS4 preserves edited Mod Loader INI"

"$installer" --path "$game" --zip "$patriot_zip" \
	--mgs1-flashback-zip "$flashback_zip" \
	--modloader-file "$modloader" --reset-ini >/dev/null
assert_eq "flashback-default=true" "$(cat "$game/MGS4/MGSM2Fix.ini")" \
	"MGS4 resets flashback INI"
assert_contains "$(cat "$game/MGS4/scripts/MGS4ModLoader.ini")" \
	"Enabled = true" "MGS4 resets Mod Loader INI"

fake_home="$TEST_TMP/home"
localconfig="$fake_home/.steam/steam/userdata/111/config/localconfig.vdf"
mkdir -p "${localconfig%/*}" "$fake_home/.steam/steam/steamapps"
cat > "$localconfig" <<'EOF'
"UserLocalConfigStore"
{
	"Software"
	{
		"Valve"
		{
			"Steam"
			{
				"apps"
				{
				"2492670"
				{
				"LaunchOptions"		"--existing %command%"
				}
			}
		}
	}
}
EOF
HOME="$fake_home" "$installer" --path "$game" --set-launch-options \
	--user 111 --yes >/dev/null
launch_config=$(cat "$localconfig")
assert_contains "$launch_config" "wininet=n,b" \
	"MGS4 launch options include PatriotFix override"
assert_contains "$launch_config" "dinput8=n,b" \
	"MGS4 launch options derive flashback override from state"
assert_contains "$launch_config" "--existing" \
	"MGS4 launch options preserve unrelated arguments"

printf 'custom-settings\n' > "$game/MGSPatriotFix.settings"
"$installer" --path "$game" --uninstall >/dev/null
assert_eq "original-patriot-loader" "$(cat "$game/MGS4/winmm.dll")" \
	"MGS4 uninstall restores PatriotFix loader"
assert_eq "original-modloader" \
	"$(cat "$game/MGS4/scripts/MGS4ModLoader.asi")" \
	"MGS4 uninstall restores prior Mod Loader file"
assert_file_exists "$game/MGS4/mods/user-mod.txt" \
	"MGS4 uninstall leaves user mods intact"
assert_eq "custom-settings" "$(cat "$game/MGSPatriotFix.settings")" \
	"MGS4 uninstall preserves PatriotFix settings"
[[ ! -e "$game/MGS4/plugins/MGSM2Fix.asi" ]] ||
	test_fail "MGS4 flashback plugin survived uninstall"
test_pass "MGS4 uninstall removes flashback MGSM2Fix"

for mode in --list --uninstall --set-launch-options; do
	set +e
	"$installer" --path "$game" --write-settings "$mode" >/dev/null 2>&1
	status=$?
	set -e
	assert_status 64 "$status" "MGS4 write settings conflicts with $mode"
done

legacy="$TEST_TMP/MGS4-legacy"
mkdir -p "$legacy/MGS4/scripts" "$legacy/MGS4/mods" \
	"$legacy/.mgspatriotfix-backup/MGS4" \
	"$legacy/MGS4/.mgsm2fix-backup"
printf 'game\n' > "$legacy/MGS4/mgs4.exe"
printf 'flashback\n' > "$legacy/MGS4/mgs1.exe"
printf 'mod-patriot\n' > "$legacy/MGS4/winmm.dll"
printf 'mod-flashback\n' > "$legacy/MGS4/dinput8.dll"
printf 'mod-loader\n' > "$legacy/MGS4/scripts/MGS4ModLoader.asi"
printf 'mod-loader-ini\n' > "$legacy/MGS4/scripts/MGS4ModLoader.ini"
printf 'user-mod\n' > "$legacy/MGS4/mods/user-mod.txt"
printf 'original-patriot\n' \
	> "$legacy/.mgspatriotfix-backup/MGS4/winmm.dll"
printf 'original-flashback\n' \
	> "$legacy/MGS4/.mgsm2fix-backup/dinput8.dll"
printf 'MGS4/winmm.dll\n' > "$legacy/.mgspatriotfix-files.txt"
printf '%s\n' \
	MGS4/scripts/MGS4ModLoader.asi \
	MGS4/scripts/MGS4ModLoader.ini \
	> "$legacy/.mgs4modloader-files.txt"
printf 'dinput8.dll\n' > "$legacy/MGS4/.mgsm2fix-files.txt"

"$installer" --path "$legacy" --uninstall >/dev/null
assert_eq "original-patriot" "$(cat "$legacy/MGS4/winmm.dll")" \
	"MGS4 restores legacy PatriotFix backup"
assert_eq "original-flashback" "$(cat "$legacy/MGS4/dinput8.dll")" \
	"MGS4 restores legacy flashback backup"
[[ ! -e "$legacy/MGS4/scripts/MGS4ModLoader.asi" ]] ||
	test_fail "Legacy MGS4 Mod Loader survived uninstall"
test_pass "MGS4 removes legacy Mod Loader state"
assert_file_exists "$legacy/MGS4/mods/user-mod.txt" \
	"MGS4 legacy uninstall preserves user mods"
