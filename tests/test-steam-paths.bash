#!/usr/bin/env bash

set -u

ROOT=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
		pwd -P
)
source "$ROOT/tests/helpers/testlib.bash"
make_test_tmp

export HOME="$TEST_TMP/home"
unset STEAM_ROOT || true
mkdir -p "$HOME"

source "$ROOT/util/steam-libraries.bash"

steam_root="$HOME/.local/share/Steam"
game_dir="$steam_root/steamapps/common/MGS1"
mkdir -p "$game_dir"
game_dir=$(cd -- "$game_dir" && pwd -P)
create_app_manifest "$steam_root" 2131630 MGS1

resolved=$(mgs_steam_path_from_appid 2131630)
assert_eq "$game_dir" "$resolved" "primary Steam library is resolved"

secondary="$TEST_TMP/Secondary Library"
secondary_game="$secondary/steamapps/common/MGS2"
mkdir -p "$secondary_game"
secondary_game=$(cd -- "$secondary_game" && pwd -P)
create_app_manifest "$secondary" 2131640 MGS2
cat > "$steam_root/steamapps/libraryfolders.vdf" <<EOF
"libraryfolders"
{
	"1"
	{
		"path"		"$secondary"
	}
}
EOF

resolved=$(mgs_steam_path_from_appid 2131640)
assert_eq "$secondary_game" "$resolved" "secondary library with spaces is resolved"

flatpak_root="$HOME/.var/app/com.valvesoftware.Steam/data/Steam"
flatpak_game="$flatpak_root/steamapps/common/MGS3"
mkdir -p "$flatpak_game"
flatpak_game=$(cd -- "$flatpak_game" && pwd -P)
create_app_manifest "$flatpak_root" 2131650 MGS3
resolved=$(mgs_steam_path_from_appid 2131650)
assert_eq "$flatpak_game" "$resolved" "Flatpak Steam library is resolved"

set +e
mgs_steam_path_from_appid bad >/dev/null 2>&1
status=$?
set -e
assert_status 64 "$status" "invalid AppID returns 64"

set +e
mgs_steam_path_from_appid 999999 >/dev/null 2>&1
status=$?
set -e
assert_status 3 "$status" "missing AppID returns 3"

create_app_manifest "$steam_root" 123456 MissingGame
set +e
mgs_steam_path_from_appid 123456 >/dev/null 2>&1
status=$?
set -e
assert_status 3 "$status" "missing install directory returns 3"

profile1="$steam_root/userdata/111/config/localconfig.vdf"
profile2="$steam_root/userdata/222/config/localconfig.vdf"
mkdir -p "${profile1%/*}" "${profile2%/*}" "$steam_root/config"
: > "$profile1"
: > "$profile2"
profile1=$(cd -- "${profile1%/*}" && printf '%s/localconfig.vdf\n' "$(pwd -P)")
profile2=$(cd -- "${profile2%/*}" && printf '%s/localconfig.vdf\n' "$(pwd -P)")
cat > "$steam_root/config/loginusers.vdf" <<'EOF'
"users"
{
	"76561197960265839"
	{
		"MostRecent"		"0"
	}
	"76561197960265950"
	{
		"MostRecent"		"1"
	}
}
EOF

selected=$(mgs_steam_pick_localconfig)
assert_eq "$profile2" "$selected" "most-recent Steam profile is selected"

selected=$(mgs_steam_pick_localconfig 111)
assert_eq "$profile1" "$selected" "explicit Steam profile is selected"

set +e
mgs_steam_pick_localconfig 333 >/dev/null 2>&1
status=$?
set -e
assert_status 1 "$status" "unknown Steam profile is rejected"

source_output=$(source "$ROOT/util/steam-path-from-appid.bash")
assert_eq "" "$source_output" "standalone resolver is quiet when sourced"

resolved=$("$ROOT/util/steam-path-from-appid.bash" 2131630)
assert_eq "$game_dir" "$resolved" "standalone resolver prints the game path"

set +e
"$ROOT/util/steam-path-from-appid.bash" nope >/dev/null 2>&1
status=$?
set -e
assert_status 64 "$status" "standalone resolver preserves invalid-usage status"

empty_home="$TEST_TMP/empty-home"
mkdir -p "$empty_home"
set +e
HOME="$empty_home" "$ROOT/util/steam-path-from-appid.bash" 2131630 >/dev/null 2>&1
status=$?
set -e
assert_status 1 "$status" "standalone resolver reports missing Steam as an error"
