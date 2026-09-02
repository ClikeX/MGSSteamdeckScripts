#!/usr/bin/env bash

set -u

ROOT=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
		pwd -P
)

status=0
count=0

for test_file in "$ROOT"/tests/test-*.bash; do
	[[ -f $test_file ]] || continue
	count=$((count + 1))
	printf '\n# %s\n' "${test_file##*/}"
	if ! bash "$test_file"; then
		status=1
	fi
done

if (( count == 0 )); then
	printf 'error: no tests found\n' >&2
	exit 1
fi

if (( status != 0 )); then
	printf '\nTest suite failed.\n' >&2
	exit "$status"
fi

printf '\nAll %d test files passed.\n' "$count"
