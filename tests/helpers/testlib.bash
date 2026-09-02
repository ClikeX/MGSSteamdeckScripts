#!/usr/bin/env bash

TESTS_RUN=0

test_fail() {
	printf 'not ok - %s\n' "$*" >&2
	exit 1
}

test_pass() {
	TESTS_RUN=$((TESTS_RUN + 1))
	printf 'ok %d - %s\n' "$TESTS_RUN" "$*"
}

assert_eq() {
	local expected=$1
	local actual=$2
	local message=${3:-values are equal}

	if [[ $expected != "$actual" ]]; then
		test_fail "$message (expected '$expected', got '$actual')"
	fi
	test_pass "$message"
}

assert_status() {
	local expected=$1
	local actual=$2
	local message=${3:-status is correct}

	if [[ $expected -ne $actual ]]; then
		test_fail "$message (expected $expected, got $actual)"
	fi
	test_pass "$message"
}

assert_file_exists() {
	local path=$1
	local message=${2:-file exists}

	[[ -f $path ]] || test_fail "$message ($path)"
	test_pass "$message"
}

assert_contains() {
	local haystack=$1
	local needle=$2
	local message=${3:-text contains expected value}

	[[ $haystack == *"$needle"* ]] ||
		test_fail "$message (missing '$needle')"
	test_pass "$message"
}

make_test_tmp() {
	TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/mgs-installers-test.XXXXXX")
	export TEST_TMP
	trap 'rm -rf "${TEST_TMP:?}"' EXIT
}

create_app_manifest() {
	local steam_root=$1
	local appid=$2
	local installdir=$3

	mkdir -p "$steam_root/steamapps"
	cat > "$steam_root/steamapps/appmanifest_$appid.acf" <<EOF
"AppState"
{
	"appid"		"$appid"
	"installdir"		"$installdir"
}
EOF
}
