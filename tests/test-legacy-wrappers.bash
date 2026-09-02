#!/usr/bin/env bash

set -u

ROOT=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
		pwd -P
)
source "$ROOT/tests/helpers/testlib.bash"

output=$("$ROOT/installers/install-mgsm2.bash" --help 2>&1)
assert_contains "$output" "deprecated" \
	"MGSM2Fix wrapper warns about deprecation"
assert_contains "$output" "Metal Gear Solid: Master Collection Version" \
	"MGSM2Fix default routes to MGS1"

output=$("$ROOT/installers/install-mgshdfix.bash" --game mgs2 --help 2>&1)
assert_contains "$output" "Metal Gear Solid 2" \
	"MGSHDFix wrapper routes MGS2"

output=$("$ROOT/installers/install-mgshdfix.bash" --game mgs3 --help 2>&1)
assert_contains "$output" "MGS3CrouchWalk" \
	"MGSHDFix wrapper routes MGS3"

output=$("$ROOT/installers/install-mgspatriotfix.bash" --game pw --help 2>&1)
assert_contains "$output" "Peace Walker" \
	"PatriotFix wrapper routes Peace Walker"

output=$("$ROOT/installers/install-mgspatriotfix.bash" --help 2>&1)
assert_contains "$output" "optional MGS4 components" \
	"PatriotFix default routes to MGS4"

output=$("$ROOT/installers/install-mgsvfix.bash" --game tpp --help 2>&1)
assert_contains "$output" "Infinite Heaven" \
	"MGSVFix wrapper routes The Phantom Pain"

output=$("$ROOT/installers/install-mgsvfix.bash" --game gz --help 2>&1)
assert_contains "$output" "Ground Zeroes" \
	"MGSVFix wrapper routes Ground Zeroes"

set +e
output=$("$ROOT/installers/install-mgshdfix.bash" --game all 2>&1)
status=$?
set -e
assert_status 64 "$status" "MGSHDFix wrapper rejects multi-game selection"
assert_contains "$output" "installers/mgs2/install-mgs2.bash" \
	"MGSHDFix wrapper prints replacement commands"
assert_contains "$output" "deprecated" \
	"ambiguous MGSHDFix wrapper still prints deprecation warning"

set +e
output=$("$ROOT/installers/install-mgsvfix.bash" 2>&1)
status=$?
set -e
assert_status 64 "$status" "MGSVFix wrapper rejects ambiguous default"
assert_contains "$output" "installers/mgsv-tpp/install-mgsv-tpp.bash" \
	"MGSVFix wrapper prints replacement commands"
assert_contains "$output" "deprecated" \
	"ambiguous MGSVFix wrapper still prints deprecation warning"

set +e
output=$("$ROOT/installers/install-mgsm2.bash" --game mgs4 --uninstall 2>&1)
status=$?
set -e
assert_status 64 "$status" \
	"legacy flashback uninstall rejects unsafe all-component delegation"
assert_contains "$output" "removes every tracked MGS4 component" \
	"legacy flashback uninstall explains the safety boundary"

set +e
"$ROOT/installers/install-mgsm2.bash" --game mgs1 --unknown \
	>/dev/null 2>&1
status=$?
set -e
assert_status 64 "$status" "legacy wrapper preserves delegated failure status"
