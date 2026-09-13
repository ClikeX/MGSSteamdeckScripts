#!/usr/bin/env bash

set -u

ROOT=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
		pwd -P
)
source "$ROOT/tests/helpers/testlib.bash"
make_test_tmp

game="$TEST_TMP/MGS2"
hdfix_payload="$TEST_TMP/mgshdfix-payload"
bugfix_payload="$TEST_TMP/bugfix-payload"
textures_2x_payload="$TEST_TMP/bugfix-2x-payload"
textures_4x_payload="$TEST_TMP/bugfix-4x-payload"
hdfix_archive="$TEST_TMP/MGSHDFix.zip"
bugfix_archive="$TEST_TMP/MGS2-Community-Bugfix-Compilation_Base.zip"
textures_2x_archive="$TEST_TMP/MGS2-Community-Bugfix-Compilation_2x.zip"
textures_4x_archive="$TEST_TMP/MGS2-Community-Bugfix-Compilation_4x.zip"
installer="$ROOT/installers/mgs2/install-mgs2.bash"
mod_order_note="$game/.mgs-installer/mgs2communitybugfix/mod-order.txt"

mkdir -p \
	"$game" \
	"$hdfix_payload/logs" \
	"$hdfix_payload/plugins" \
	"$bugfix_payload/plugins" \
	"$bugfix_payload/textures/flatlist/_win" \
	"$bugfix_payload/us/demo/_bp" \
	"$textures_2x_payload/textures/flatlist/ovr_stm/_win" \
	"$textures_2x_payload/textures/flatlist/ovr_stm/ovr_eu/_win" \
	"$textures_4x_payload/textures/flatlist/ovr_stm/_win" \
	"$textures_4x_payload/textures/flatlist/ovr_stm/ovr_eu/_win"
printf 'game\n' > "$game/METAL GEAR SOLID2.exe"
printf 'original-loader\n' > "$game/wininet.dll"

printf 'log\n' > "$hdfix_payload/logs/MGSHDFix_Game.log"
printf 'MZtool\n' > "$hdfix_payload/plugins/MGSHDFix Config Tool.exe"
printf 'MZplugin\n' > "$hdfix_payload/plugins/MGSHDFix.asi"
printf 'MZhttp\n' > "$hdfix_payload/winhttp.dll"
printf 'MZinet\n' > "$hdfix_payload/wininet.dll"
(cd "$hdfix_payload" && zip -qr "$hdfix_archive" .)

printf 'bugfix-asi\n' > "$bugfix_payload/plugins/MGS2-Community-Bugfix-Compilation.asi"
printf 'bugfix-default\n' > "$bugfix_payload/plugins/MGS2-Community-Bugfix-Compilation.ini"
printf 'base-texture\n' > "$bugfix_payload/textures/flatlist/_win/chr1_05_alp_sub_ovl.bmp.ctxr"
printf 'audio-fix\n' > "$bugfix_payload/us/demo/_bp/p010_01_p01g.sdt"
(cd "$bugfix_payload" && zip -qr "$bugfix_archive" .)

printf '2x-orange\n' > "$textures_2x_payload/textures/flatlist/ovr_stm/_win/col_orange2.bmp.ctxr"
printf '2x-card\n' > "$textures_2x_payload/textures/flatlist/ovr_stm/ovr_eu/_win/seculitycard_lv2_alp.bmp.ctxr"
(cd "$textures_2x_payload" && zip -qr "$textures_2x_archive" .)

printf '4x-orange\n' > "$textures_4x_payload/textures/flatlist/ovr_stm/_win/col_orange2.bmp.ctxr"
printf '4x-card\n' > "$textures_4x_payload/textures/flatlist/ovr_stm/ovr_eu/_win/seculitycard_lv2_alp.bmp.ctxr"
(cd "$textures_4x_payload" && zip -qr "$textures_4x_archive" .)

output=$(
	"$installer" --path "$game" --zip "$hdfix_archive" \
		--community-bugfix-zip "$bugfix_archive"
)
game=$(
	cd -- "$game" &&
		pwd -P
)
mod_order_note="$game/.mgs-installer/mgs2communitybugfix/mod-order.txt"
assert_file_exists "$game/plugins/MGSHDFix.asi" \
	"MGS2 installs MGSHDFix plugin"
assert_file_exists "$game/plugins/MGS2-Community-Bugfix-Compilation.asi" \
	"MGS2 installs the Community Bugfix plugin"
assert_file_exists "$game/plugins/MGS2-Community-Bugfix-Compilation.ini" \
	"MGS2 installs the Community Bugfix INI"
assert_file_exists "$mod_order_note" \
	"MGS2 writes the Community Bugfix mod-order note"
assert_eq "base-texture" \
	"$(cat "$game/textures/flatlist/_win/chr1_05_alp_sub_ovl.bmp.ctxr")" \
	"MGS2 installs Community Bugfix base assets"
[[ ! -e "$game/logs/MGSHDFix_Game.log" ]] ||
	test_fail "MGS2 installed excluded release logs"
test_pass "MGS2 excludes release logs"
assert_contains "$output" "$game/plugins/MGSHDFix Config Tool.exe" \
	"MGS2 reports the discovered configuration tool"
assert_contains "$output" "$mod_order_note" \
	"MGS2 reports the mod-order note path"
assert_contains "$(cat "$mod_order_note")" \
	"MGS2 Community Bugfix Compilation - AI Upscaled Texture Add-on" \
	"MGS2 writes Community Bugfix load-order guidance"

printf 'user-settings\n' > "$game/plugins/MGSHDFix.settings"
printf 'user-bugfix\n' > "$game/plugins/MGS2-Community-Bugfix-Compilation.ini"
"$installer" --path "$game" --zip "$hdfix_archive" \
	--community-bugfix-zip "$bugfix_archive" \
	--textures-2x-zip "$textures_2x_archive" >/dev/null
assert_eq "user-settings" "$(cat "$game/plugins/MGSHDFix.settings")" \
	"MGS2 preserves generated MGSHDFix settings"
assert_eq "user-bugfix" "$(cat "$game/plugins/MGS2-Community-Bugfix-Compilation.ini")" \
	"MGS2 preserves edited Community Bugfix INI"
assert_eq "bugfix-default" \
	"$(cat "$game/plugins/MGS2-Community-Bugfix-Compilation.ini.new")" \
	"MGS2 writes new Community Bugfix defaults beside edited INI"
assert_eq "2x-orange" \
	"$(cat "$game/textures/flatlist/ovr_stm/_win/col_orange2.bmp.ctxr")" \
	"MGS2 installs the 2x texture add-on"

"$installer" --path "$game" --zip "$hdfix_archive" \
	--community-bugfix-zip "$bugfix_archive" \
	--textures-4x-zip "$textures_4x_archive" >/dev/null
assert_eq "4x-orange" \
	"$(cat "$game/textures/flatlist/ovr_stm/_win/col_orange2.bmp.ctxr")" \
	"MGS2 switches from the 2x to the 4x texture add-on"
list_output=$("$installer" --path "$game" --list)
assert_contains "$list_output" \
	"MGS2 Community Bugfix 2x texture add-on: not installed by this installer" \
	"MGS2 clears the old 2x texture state after switching to 4x"
assert_contains "$list_output" \
	"MGS2 Community Bugfix 4x texture add-on: installed" \
	"MGS2 tracks the 4x texture state"

"$installer" --path "$game" --zip "$hdfix_archive" \
	--community-bugfix-zip "$bugfix_archive" \
	--reset-ini >/dev/null
assert_eq "bugfix-default" \
	"$(cat "$game/plugins/MGS2-Community-Bugfix-Compilation.ini")" \
	"MGS2 resets the Community Bugfix INI when requested"

set +e
"$installer" --path "$game" --zip "$hdfix_archive" \
	--no-community-bugfix --textures-2x-zip "$textures_2x_archive" \
	>/dev/null 2>&1
status=$?
set -e
assert_status 64 "$status" \
	"MGS2 rejects texture add-ons without the Community Bugfix base"

"$installer" --path "$game" --uninstall >/dev/null
assert_eq "original-loader" "$(cat "$game/wininet.dll")" \
	"MGS2 uninstall restores the original loader"
assert_eq "user-settings" "$(cat "$game/plugins/MGSHDFix.settings")" \
	"MGS2 uninstall preserves generated MGSHDFix settings"
[[ ! -e "$game/plugins/MGS2-Community-Bugfix-Compilation.asi" ]] ||
	test_fail "MGS2 Community Bugfix plugin survived uninstall"
test_pass "MGS2 uninstall removes the Community Bugfix plugin"
[[ ! -e "$game/textures/flatlist/ovr_stm/_win/col_orange2.bmp.ctxr" ]] ||
	test_fail "MGS2 texture add-on survived uninstall"
test_pass "MGS2 uninstall removes the Community Bugfix texture add-on"
[[ ! -e "$game/plugins/MGS2-Community-Bugfix-Compilation.ini" ]] ||
	test_fail "MGS2 Community Bugfix INI survived uninstall"
test_pass "MGS2 uninstall removes the Community Bugfix INI"
[[ ! -e "$mod_order_note" ]] ||
	test_fail "MGS2 mod-order note survived uninstall"
test_pass "MGS2 uninstall removes the mod-order note"
