#!/usr/bin/env bash

set -u

ROOT=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
		pwd -P
)
source "$ROOT/tests/helpers/testlib.bash"
make_test_tmp

payload="$TEST_TMP/payload"
archive="$TEST_TMP/MGSM2Fix.zip"
mkdir -p "$payload/plugins"
printf 'MZplugin\n' > "$payload/plugins/MGSM2Fix.asi"
printf 'MZloader\n' > "$payload/dinput8.dll"
printf 'stock=true\n' > "$payload/MGSM2Fix.ini"
(cd "$payload" && zip -qr "$archive" .)

test_bonus_installer() {
	local label=$1
	local directory=$2
	local marker=$3
	local installer=$4
	local game="$TEST_TMP/$directory"

	mkdir -p "$game"
	printf 'game\n' > "$game/$marker"
	printf 'original-loader\n' > "$game/dinput8.dll"

	"$installer" --path "$game" --zip "$archive" >/dev/null
	assert_file_exists "$game/plugins/MGSM2Fix.asi" \
		"$label installs MGSM2Fix plugin"
	assert_eq "stock=true" "$(cat "$game/MGSM2Fix.ini")" \
		"$label creates missing INI"

	printf 'user=true\n' > "$game/MGSM2Fix.ini"
	"$installer" --path "$game" --zip "$archive" >/dev/null
	assert_eq "user=true" "$(cat "$game/MGSM2Fix.ini")" \
		"$label preserves edited INI"
	assert_eq "stock=true" "$(cat "$game/MGSM2Fix.ini.new")" \
		"$label writes new defaults"

	"$installer" --path "$game" --uninstall >/dev/null
	assert_eq "original-loader" "$(cat "$game/dinput8.dll")" \
		"$label uninstall restores original loader"
	[[ ! -e "$game/plugins/MGSM2Fix.asi" ]] ||
		test_fail "$label plugin survived uninstall"
	test_pass "$label uninstall removes tracked plugin"
}

test_bonus_installer "Vol. 1 bonus" "MC1" "MGS MC1 Bonus Content.exe" \
	"$ROOT/installers/mc-vol1-bonus/install-mc-vol1-bonus.bash"
test_bonus_installer "Vol. 2 bonus" "MC2" "MGS MC2 Bonus Content.exe" \
	"$ROOT/installers/mc-vol2-bonus/install-mc-vol2-bonus.bash"
