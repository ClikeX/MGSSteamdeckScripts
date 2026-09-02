#!/usr/bin/env bash

mgs_canonical_dir() {
	local directory=$1

	[[ -d $directory ]] || return 1
	(
		cd -- "$directory" &&
			pwd -P
	)
}

mgs_vdf_value() {
	local key=$1
	local file=$2

	sed -n "s/.*\"$key\"[[:space:]]*\"\\(.*\\)\".*/\\1/p" "$file" | head -n1
}

mgs_steam_roots() {
	local candidate

	for candidate in \
		"${STEAM_ROOT:-}" \
		"$HOME/.steam/steam" \
		"$HOME/.steam/root" \
		"$HOME/.local/share/Steam" \
		"$HOME/.var/app/com.valvesoftware.Steam/data/Steam" \
		"$HOME/Library/Application Support/Steam"; do
		[[ -n $candidate && -d $candidate/steamapps ]] || continue
		mgs_canonical_dir "$candidate"
	done | awk 'NF && !seen[$0]++'
}

mgs_steam_library_paths() {
	local root libraryfolders path

	while IFS= read -r root; do
		[[ -n $root ]] || continue
		printf '%s\n' "$root"
		libraryfolders=$root/steamapps/libraryfolders.vdf
		[[ -r $libraryfolders ]] || continue
		while IFS= read -r path; do
			[[ -n $path && -d $path/steamapps ]] || continue
			mgs_canonical_dir "$path"
		done < <(sed -n 's/.*"path"[[:space:]]*"\(.*\)".*/\1/p' "$libraryfolders")
	done < <(mgs_steam_roots) | awk 'NF && !seen[$0]++'
}

mgs_steamapps_dirs() {
	local library

	while IFS= read -r library; do
		[[ -n $library && -d $library/steamapps ]] || continue
		printf '%s\n' "$library/steamapps"
	done < <(mgs_steam_library_paths)
}

mgs_find_app_manifest() {
	local appid=$1
	local steamapps manifest found_steam=0

	while IFS= read -r steamapps; do
		found_steam=1
		manifest=$steamapps/appmanifest_$appid.acf
		if [[ -r $manifest ]]; then
			printf '%s\n' "$manifest"
			return 0
		fi
	done < <(mgs_steamapps_dirs)

	if (( found_steam == 0 )); then
		printf 'no Steam installation found (set STEAM_ROOT to override)\n' >&2
		return 1
	fi

	return 3
}

mgs_steam_path_from_appid() {
	local appid=$1
	local manifest installdir target steamapps status

	if [[ ! $appid =~ ^[0-9]+$ ]]; then
		printf 'not a valid AppID: %q\n' "$appid" >&2
		return 64
	fi

	if manifest=$(mgs_find_app_manifest "$appid"); then
		:
	else
		status=$?
		return "$status"
	fi

	installdir=$(mgs_vdf_value installdir "$manifest")
	if [[ -z $installdir ]]; then
		printf 'no installdir in %s\n' "$manifest" >&2
		return 1
	fi

	steamapps=${manifest%/*}
	target=$steamapps/common/$installdir
	if [[ ! -d $target ]]; then
		printf 'manifest points at a missing directory: %s\n' "$target" >&2
		return 3
	fi

	mgs_canonical_dir "$target"
}

mgs_steam_localconfigs() {
	local root config

	while IFS= read -r root; do
		for config in "$root"/userdata/*/config/localconfig.vdf; do
			[[ -f $config ]] || continue
			printf '%s\n' "$config"
		done
	done < <(mgs_steam_roots) | awk 'NF && !seen[$0]++'
}

mgs_steam_recent_account_id() {
	local root loginusers steamid64

	while IFS= read -r root; do
		loginusers=$root/config/loginusers.vdf
		[[ -r $loginusers ]] || continue
		steamid64=$(
			awk '
				/^[[:space:]]*"[0-9]+"/ {
					id = $1
					gsub(/"/, "", id)
				}
				/"MostRecent"[[:space:]]*"1"/ {
					print id
					exit
				}
			' "$loginusers"
		)
		if [[ -n $steamid64 ]]; then
			printf '%s\n' "$((steamid64 - 76561197960265728))"
			return 0
		fi
	done < <(mgs_steam_roots)

	return 1
}

mgs_steam_pick_localconfig() {
	local requested_account=${1-}
	local recent_account config
	local -a configs=()

	if [[ -n $requested_account && ! $requested_account =~ ^[0-9]+$ ]]; then
		printf 'invalid Steam account ID: %s\n' "$requested_account" >&2
		return 64
	fi

	while IFS= read -r config; do
		[[ -n $config ]] && configs+=("$config")
	done < <(mgs_steam_localconfigs)

	if [[ -n $requested_account ]]; then
		for config in "${configs[@]}"; do
			if [[ $config == */userdata/"$requested_account"/config/localconfig.vdf ]]; then
				printf '%s\n' "$config"
				return 0
			fi
		done
		printf 'no Steam profile found for account %s\n' "$requested_account" >&2
		return 1
	fi

	if recent_account=$(mgs_steam_recent_account_id); then
		for config in "${configs[@]}"; do
			if [[ $config == */userdata/"$recent_account"/config/localconfig.vdf ]]; then
				printf '%s\n' "$config"
				return 0
			fi
		done
	fi

	case ${#configs[@]} in
		0)
			printf 'no Steam user profile found\n' >&2
			return 1
			;;
		1)
			printf '%s\n' "${configs[0]}"
			return 0
			;;
		*)
			printf 'several Steam accounts found; select one with --user <id>:\n' >&2
			for config in "${configs[@]}"; do
				printf '  %s\n' "${config#*/userdata/}" >&2
			done
			return 1
			;;
	esac
}
