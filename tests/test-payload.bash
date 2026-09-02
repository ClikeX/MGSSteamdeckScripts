#!/usr/bin/env bash

set -u

ROOT=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
		pwd -P
)
source "$ROOT/tests/helpers/testlib.bash"
source "$ROOT/util/payload.bash"
make_test_tmp

source_dir="$TEST_TMP/source"
target="$TEST_TMP/game"
mkdir -p "$source_dir/plugins" "$source_dir/logs" "$target"
printf 'MZmod\n' > "$source_dir/plugins/Fix.asi"
printf 'stock=true\n' > "$source_dir/Fix.ini"
printf 'log\n' > "$source_dir/logs/build.log"

inis=(Fix.ini)
stale=(OldFix.asi)
mgs_payload_install "$target" "$source_dir" testfix 0 0 '^logs/' \
	'\.(asi|dll)$' inis stale
assert_file_exists "$target/plugins/Fix.asi" "payload file is installed"
assert_eq "stock=true" "$(cat "$target/Fix.ini")" "missing INI is created"
[[ ! -e "$target/logs/build.log" ]] || test_fail "excluded log was installed"
test_pass "excluded paths are not installed"

printf 'user=true\n' > "$target/Fix.ini"
printf 'stock=false\n' > "$source_dir/Fix.ini"
mgs_payload_install "$target" "$source_dir" testfix 0 0 '^logs/' \
	'\.(asi|dll)$' inis stale
assert_eq "user=true" "$(cat "$target/Fix.ini")" "existing INI is preserved"
assert_eq "stock=false" "$(cat "$target/Fix.ini.new")" "new defaults are written beside INI"

mgs_payload_install "$target" "$source_dir" testfix 1 0 '^logs/' \
	'\.(asi|dll)$' inis stale
assert_eq "stock=false" "$(cat "$target/Fix.ini")" "reset replaces the INI"
[[ ! -e "$target/Fix.ini.new" ]] || test_fail "obsolete INI defaults were orphaned"
test_pass "obsolete INI defaults are removed"

printf 'legacy\n' > "$target/OldFix.asi"
mgs_payload_install "$target" "$source_dir" testfix 0 0 '^logs/' \
	'\.(asi|dll)$' inis stale
[[ ! -e "$target/OldFix.asi" ]] || test_fail "tracked stale file was not removed"
test_pass "tracked stale path is removed"

fresh="$TEST_TMP/fresh"
mkdir -p "$fresh"
printf 'unrelated\n' > "$fresh/OldFix.asi"
stderr=$(
	mgs_payload_install "$fresh" "$source_dir" newfix 0 0 '^logs/' \
		'\.(asi|dll)$' inis stale 2>&1 >/dev/null
)
assert_file_exists "$fresh/OldFix.asi" "untracked stale path survives first install"
case "$stderr" in
	*"was not removed"*) test_pass "untracked stale path emits warning" ;;
	*) test_fail "untracked stale path warning was missing" ;;
esac

dry="$TEST_TMP/dry"
mkdir -p "$dry"
mgs_payload_install "$dry" "$source_dir" dryfix 0 1 '^logs/' \
	'\.(asi|dll)$' inis stale >/dev/null
[[ ! -e "$dry/plugins/Fix.asi" ]] || test_fail "dry-run modified target"
test_pass "dry-run leaves target unchanged"
