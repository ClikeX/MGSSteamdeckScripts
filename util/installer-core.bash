#!/usr/bin/env bash

mgs_installer_init() {
	local installer_source=$1

	MGS_INSTALLER_DIR=$(
		cd -- "$(dirname -- "$installer_source")" &&
			pwd -P
	)
	MGS_REPO_ROOT=$(
		cd -- "$MGS_INSTALLER_DIR/../.." &&
			pwd -P
	)
	MGS_UTIL_DIR=$MGS_REPO_ROOT/util

	# shellcheck source=util/output.bash
	source "$MGS_UTIL_DIR/output.bash"
	# shellcheck source=util/dependencies.bash
	source "$MGS_UTIL_DIR/dependencies.bash"
	# shellcheck source=util/cli.bash
	source "$MGS_UTIL_DIR/cli.bash"
	# shellcheck source=util/steam-libraries.bash
	source "$MGS_UTIL_DIR/steam-libraries.bash"
	# shellcheck source=util/install-state.bash
	source "$MGS_UTIL_DIR/install-state.bash"
	# shellcheck source=util/payload.bash
	source "$MGS_UTIL_DIR/payload.bash"
}

mgs_installer_create_workspace() {
	local prefix=${1:-mgs-installer}

	MGS_WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/$prefix.XXXXXX") || return
	trap mgs_installer_cleanup EXIT
}

mgs_installer_cleanup() {
	if [[ -n ${MGS_WORK_DIR:-} && -d $MGS_WORK_DIR ]]; then
		rm -rf "$MGS_WORK_DIR"
	fi
}

mgs_installer_resolve_target() {
	local appid=$1
	local marker=$2
	local target

	if [[ -n $MGS_CLI_PATH ]]; then
		[[ -d $MGS_CLI_PATH ]] || {
			mgs_error "game path does not exist: $MGS_CLI_PATH"
			return 1
		}
		target=$(
			cd -- "$MGS_CLI_PATH" &&
				pwd -P
		)
	else
		if ! target=$(mgs_steam_path_from_appid "$appid"); then
			mgs_error "could not find Steam AppID $appid"
			return 1
		fi
	fi

	if [[ ! -e $target/$marker ]]; then
		if (( MGS_CLI_ASSUME_YES )); then
			mgs_warn "expected game marker is missing: $target/$marker"
		else
			mgs_error "expected game marker is missing: $target/$marker"
			return 1
		fi
	fi

	printf '%s\n' "$target"
}

mgs_installer_absolute_file() {
	local path=$1
	local directory filename

	[[ -f $path ]] || {
		mgs_error "file does not exist: $path"
		return 1
	}
	directory=$(dirname -- "$path")
	filename=$(basename -- "$path")
	directory=$(
		cd -- "$directory" &&
			pwd -P
	)
	printf '%s/%s\n' "$directory" "$filename"
}

mgs_installer_github_release() {
	local repo=$1
	local match_regex=${2-}
	local reject_regex=${3-}
	local extension_regex=${4:-\\.zip$}
	local version=${5-${MGS_CLI_VERSION}}
	local -a command=(
		"$MGS_UTIL_DIR/release_github.py"
		"$repo"
		--extension "$extension_regex"
	)

	[[ -n $version ]] && command+=(--tag "$version")
	[[ -n $match_regex ]] && command+=(--match "$match_regex")
	[[ -n $reject_regex ]] && command+=(--reject "$reject_regex")
	"${command[@]}"
}

mgs_installer_forgejo_release() {
	local base_url=$1
	local repo=$2
	local match_regex=${3-}
	local reject_regex=${4-}
	local extension_regex=${5:-\\.zip$}
	local version=${6-${MGS_CLI_VERSION}}
	local -a command=(
		"$MGS_UTIL_DIR/release_forgejo.py"
		"$base_url"
		"$repo"
		--extension "$extension_regex"
	)

	[[ -n $version ]] && command+=(--tag "$version")
	[[ -n $match_regex ]] && command+=(--match "$match_regex")
	[[ -n $reject_regex ]] && command+=(--reject "$reject_regex")
	"${command[@]}"
}

mgs_installer_download() {
	local url=$1
	local destination=$2

	curl -fL --progress-bar "$url" -o "$destination"
}

mgs_installer_extract_archive() {
	local archive=$1
	local destination=$2

	"$MGS_UTIL_DIR/archive.py" extract "$archive" "$destination" || return
	"$MGS_UTIL_DIR/archive.py" root "$destination"
}

mgs_installer_steam_running() {
	pgrep -x steam >/dev/null 2>&1 ||
		pgrep -x steamwebhelper >/dev/null 2>&1
}

mgs_installer_set_launch_options() {
	local appid=$1
	local overrides=$2
	local localconfig
	local -a command

	mgs_require_command python3 || return
	if mgs_installer_steam_running && (( ! MGS_CLI_ASSUME_YES )); then
		mgs_error "Steam is running; close it before changing launch options"
		return 1
	fi
	if mgs_installer_steam_running; then
		mgs_warn "Steam is running and may overwrite this change when it exits"
	fi

	localconfig=$(mgs_steam_pick_localconfig "$MGS_CLI_STEAM_USER") || return
	command=(
		"$MGS_UTIL_DIR/steam_launch_options.py"
		"$localconfig"
		"$appid"
		--overrides "$overrides"
	)
	(( MGS_CLI_DRY_RUN )) && command+=(--dry-run)
	"${command[@]}"
}
