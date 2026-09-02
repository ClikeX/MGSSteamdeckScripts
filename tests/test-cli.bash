#!/usr/bin/env bash

set -u

ROOT=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
		pwd -P
)
source "$ROOT/tests/helpers/testlib.bash"
source "$ROOT/util/cli.bash"

game_parser() {
	case "$1" in
		--write-settings)
			MGS_CLI_CONSUMED=1
			mgs_cli_set_exclusive write-settings
			;;
		--component)
			MGS_CLI_CONSUMED=1
			mgs_cli_mark_install_selection
			;;
		*) return 1 ;;
	esac
}

mgs_cli_parse game_parser --path "/tmp/Game Path" --dry-run --yes
assert_eq "/tmp/Game Path" "$MGS_CLI_PATH" "path with spaces is preserved"
assert_eq "1" "$MGS_CLI_DRY_RUN" "dry-run is enabled"
assert_eq "1" "$MGS_CLI_ASSUME_YES" "yes is enabled"

mgs_cli_parse game_parser --zip=release.zip --reset-ini
assert_eq "release.zip" "$MGS_CLI_ZIP" "equals-form ZIP is parsed"
assert_eq "1" "$MGS_CLI_RESET_INI" "reset INI is parsed"

mgs_cli_parse game_parser --version v1.2.3
assert_eq "v1.2.3" "$MGS_CLI_VERSION" "version is parsed"

set +e
mgs_cli_parse game_parser --zip release.zip --version v1.2.3 >/dev/null 2>&1
status=$?
set -e
assert_status 64 "$status" "ZIP and version cannot be combined"

set +e
mgs_cli_parse game_parser --list --uninstall >/dev/null 2>&1
status=$?
set -e
assert_status 64 "$status" "multiple exclusive modes are rejected"

set +e
mgs_cli_parse game_parser --write-settings --zip file.zip >/dev/null 2>&1
status=$?
set -e
assert_status 64 "$status" "game exclusive mode rejects install options"

set +e
mgs_cli_parse game_parser --user 12345 >/dev/null 2>&1
status=$?
set -e
assert_status 64 "$status" "Steam user requires launch-option mode"

set +e
mgs_cli_parse game_parser --unknown >/dev/null 2>&1
status=$?
set -e
assert_status 64 "$status" "unknown options are rejected"

set +e
mgs_cli_parse game_parser --path >/dev/null 2>&1
status=$?
set -e
assert_status 64 "$status" "missing option values are rejected"
