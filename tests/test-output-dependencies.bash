#!/usr/bin/env bash

set -u

ROOT=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
		pwd -P
)
source "$ROOT/tests/helpers/testlib.bash"
source "$ROOT/util/output.bash"
source "$ROOT/util/dependencies.bash"

assert_eq "" "$MGS_COLOR_RED" "color is disabled for redirected test output"

stdout=$(mgs_info "hello")
assert_eq "hello" "$stdout" "info writes to stdout"

stderr=$(mgs_warn "careful" 2>&1 >/dev/null)
assert_eq "warn: careful" "$stderr" "warnings use stderr"

mgs_require_command sh
test_pass "existing dependency is accepted"

set +e
mgs_require_command mgs-command-that-does-not-exist >/dev/null 2>&1
status=$?
set -e
assert_status 1 "$status" "missing dependency is rejected"

selected=$(mgs_require_one_of mgs-command-that-does-not-exist sh)
assert_eq "sh" "$selected" "first available dependency is selected"
