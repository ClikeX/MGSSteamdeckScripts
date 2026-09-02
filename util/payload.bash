#!/usr/bin/env bash

MGS_PAYLOAD_UTIL_DIR=$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
		pwd -P
)
# shellcheck source=util/install-state.bash
source "$MGS_PAYLOAD_UTIL_DIR/install-state.bash"

mgs_payload_files() {
	local source_dir=$1
	local exclude_regex=${2-}

	(
		cd -- "$source_dir" || exit
		find . -type f -print |
			sed 's|^\./||' |
			{
				if [[ -n $exclude_regex ]]; then
					grep -Ev -- "$exclude_regex" || true
				else
					cat
				fi
			} |
			LC_ALL=C sort
	)
}

mgs_payload_validate_marker() {
	local source_dir=$1
	local marker_regex=$2
	local exclude_regex=${3-}

	mgs_payload_files "$source_dir" "$exclude_regex" |
		grep -Eiq -- "$marker_regex"
}

mgs_payload_list_contains() {
	local needle=$1
	shift
	local item

	for item in "$@"; do
		[[ $item == "$needle" ]] && return 0
	done
	return 1
}

mgs_payload_install() {
	local target=$1
	local source_dir=$2
	local component=$3
	local reset_ini=$4
	local dry_run=$5
	local exclude_regex=$6
	local marker_regex=$7
	local ini_array_name=$8
	local stale_array_name=$9
	local -n ini_paths=$ini_array_name
	local -n stale_paths=$stale_array_name
	local -a files=() manifest_entries=() previous_owned=()
	local relative_path destination defaults_file manifest_tmp stale_path
	local had_state=0

	[[ -d $target && -d $source_dir ]] || {
		printf 'error: payload source or target directory is missing\n' >&2
		return 1
	}
	[[ -w $target || $dry_run -eq 1 ]] || {
		printf 'error: target is not writable: %s\n' "$target" >&2
		return 1
	}

	while IFS= read -r relative_path; do
		[[ -n $relative_path ]] && files+=("$relative_path")
	done < <(mgs_payload_files "$source_dir" "$exclude_regex")

	(( ${#files[@]} )) || {
		printf 'error: payload is empty\n' >&2
		return 1
	}
	mgs_payload_validate_marker "$source_dir" "$marker_regex" "$exclude_regex" || {
		printf 'error: payload does not contain an expected component file\n' >&2
		return 1
	}

	mgs_state_has_state "$target" "$component" && had_state=1
	while IFS= read -r relative_path; do
		[[ -n $relative_path ]] && previous_owned+=("$relative_path")
	done < <(mgs_state_owned_files "$target" "$component")

	for stale_path in "${stale_paths[@]}"; do
		[[ -e $target/$stale_path ]] || continue
		mgs_payload_list_contains "$stale_path" "${files[@]}" && continue
		if (( had_state == 0 )); then
			printf 'warn: existing untracked legacy path was not removed: %s\n' "$stale_path" >&2
			continue
		fi
		if (( dry_run )); then
			printf 'would remove stale %s\n' "$stale_path"
			continue
		fi
		if ! mgs_state_is_owned "$target" "$component" "$stale_path"; then
			mgs_state_backup_file "$target" "$component" "$stale_path" || return
		fi
		rm -f "$target/$stale_path" || return
	done

	for relative_path in "${files[@]}"; do
		destination=$target/$relative_path

		if mgs_payload_list_contains "$relative_path" "${ini_paths[@]}"; then
			if [[ ! -e $destination ]]; then
				if (( dry_run )); then
					printf 'would create INI %s\n' "$relative_path"
				else
					mkdir -p "$(dirname -- "$destination")" || return
					cp -f "$source_dir/$relative_path" "$destination" || return
				fi
				manifest_entries+=("$relative_path")
				continue
			fi

			if (( reset_ini )); then
				if (( dry_run )); then
					printf 'would back up and reset INI %s\n' "$relative_path"
				else
					mgs_state_backup_file "$target" "$component" "$relative_path" || return
					cp -f "$source_dir/$relative_path" "$destination" || return
				fi
				manifest_entries+=("$relative_path")
				continue
			fi

			if mgs_state_is_owned "$target" "$component" "$relative_path"; then
				manifest_entries+=("$relative_path")
			fi
			if ! cmp -s "$source_dir/$relative_path" "$destination"; then
				defaults_file=$relative_path.new
				if (( dry_run )); then
					printf 'would preserve %s and write %s\n' "$relative_path" "$defaults_file"
				else
					mkdir -p "$(dirname -- "$target/$defaults_file")" || return
					cp -f "$source_dir/$relative_path" "$target/$defaults_file" || return
				fi
				manifest_entries+=("$defaults_file")
			fi
			continue
		fi

		if [[ -e $destination ]] &&
			! mgs_state_is_owned "$target" "$component" "$relative_path"; then
			if (( dry_run )); then
				printf 'would back up and overwrite %s\n' "$relative_path"
			else
				mgs_state_backup_file "$target" "$component" "$relative_path" || return
			fi
		elif (( dry_run )); then
			printf 'would install %s\n' "$relative_path"
		fi

		if (( ! dry_run )); then
			mkdir -p "$(dirname -- "$destination")" || return
			cp -f "$source_dir/$relative_path" "$destination" || return
		fi
		manifest_entries+=("$relative_path")
	done

	for relative_path in "${previous_owned[@]}"; do
		mgs_payload_list_contains "$relative_path" "${manifest_entries[@]}" && continue
		mgs_payload_list_contains "$relative_path" "${ini_paths[@]}" && continue
		[[ -e $target/$relative_path ]] || continue
		if (( dry_run )); then
			printf 'would remove previously installed %s\n' "$relative_path"
		else
			rm -f "$target/$relative_path" || return
		fi
	done

	if (( dry_run )); then
		return 0
	fi

	manifest_tmp=$(mktemp "${TMPDIR:-/tmp}/mgs-payload-manifest.XXXXXX") || return
	printf '%s\n' "${manifest_entries[@]}" > "$manifest_tmp"
	if ! mgs_state_write_manifest "$target" "$component" "$manifest_tmp"; then
		rm -f "$manifest_tmp"
		return 1
	fi
	rm -f "$manifest_tmp"
}
