#!/usr/bin/env bash

mgs_state_dir() {
	printf '%s/.mgs-installer/%s\n' "$1" "$2"
}

mgs_state_manifest() {
	printf '%s/files.txt\n' "$(mgs_state_dir "$1" "$2")"
}

mgs_state_backup_dir() {
	printf '%s/backup\n' "$(mgs_state_dir "$1" "$2")"
}

mgs_state_legacy_manifest() {
	local target=$1
	local component=$2

	case "$component" in
		mgshdfix) printf '%s/.mgshdfix-files.txt\n' "$target" ;;
		mgs3crouchwalk) printf '%s/.mgs3crouchwalk-files.txt\n' "$target" ;;
		mgsm2fix) printf '%s/.mgsm2fix-files.txt\n' "$target" ;;
		mgspatriotfix) printf '%s/.mgspatriotfix-files.txt\n' "$target" ;;
		mgs4modloader) printf '%s/.mgs4modloader-files.txt\n' "$target" ;;
		mgsvfix) printf '%s/.mgsvfix-manifest.txt\n' "$target" ;;
	esac
}

mgs_state_legacy_backup_dirs() {
	local target=$1
	local component=$2
	local directory

	case "$component" in
		mgshdfix|mgs3crouchwalk)
			printf '%s/.mgshdfix-backup\n' "$target"
			;;
		mgsm2fix)
			printf '%s/.mgsm2fix-backup\n' "$target"
			;;
		mgspatriotfix)
			printf '%s/.mgspatriotfix-backup\n' "$target"
			;;
		mgsvfix)
			for directory in "$target"/.mgsvfix-backup-*; do
				[[ -d $directory ]] && printf '%s\n' "$directory"
			done | LC_ALL=C sort -r
			;;
	esac
}

mgs_state_has_state() {
	local current legacy

	current=$(mgs_state_manifest "$1" "$2")
	legacy=$(mgs_state_legacy_manifest "$1" "$2")
	[[ -f $current || -n $legacy && -f $legacy ]]
}

mgs_state_owned_files() {
	local target=$1
	local component=$2
	local current legacy

	current=$(mgs_state_manifest "$target" "$component")
	legacy=$(mgs_state_legacy_manifest "$target" "$component")
	{
		[[ -f $current ]] && cat "$current"
		[[ -n $legacy && -f $legacy ]] && cat "$legacy"
		true
	} | awk 'NF && !seen[$0]++'
}

mgs_state_is_owned() {
	local target=$1
	local component=$2
	local relative_path=$3

	mgs_state_owned_files "$target" "$component" |
		grep -Fqx -- "$relative_path"
}

mgs_state_find_backup() {
	local target=$1
	local component=$2
	local relative_path=$3
	local current legacy

	current=$(mgs_state_backup_dir "$target" "$component")/$relative_path
	if [[ -e $current ]]; then
		printf '%s\n' "$current"
		return 0
	fi

	while IFS= read -r legacy; do
		[[ -n $legacy ]] || continue
		if [[ -e $legacy/$relative_path ]]; then
			printf '%s\n' "$legacy/$relative_path"
			return 0
		fi
	done < <(mgs_state_legacy_backup_dirs "$target" "$component")

	return 1
}

mgs_state_backup_file() {
	local target=$1
	local component=$2
	local relative_path=$3
	local source=$target/$relative_path
	local destination

	[[ -e $source ]] || return 0
	if mgs_state_find_backup "$target" "$component" "$relative_path" >/dev/null; then
		return 0
	fi

	destination=$(mgs_state_backup_dir "$target" "$component")/$relative_path
	mkdir -p "$(dirname -- "$destination")" || return
	cp -a "$source" "$destination"
}

mgs_state_write_manifest() {
	local target=$1
	local component=$2
	local source_file=$3
	local manifest state_dir temporary

	state_dir=$(mgs_state_dir "$target" "$component")
	manifest=$state_dir/files.txt
	mkdir -p "$state_dir" || return
	temporary=$state_dir/files.txt.tmp.$$
	awk 'NF && !seen[$0]++' "$source_file" > "$temporary" || {
		rm -f "$temporary"
		return 1
	}
	mv "$temporary" "$manifest"
}

mgs_state_restore_owned_backups() {
	local target=$1
	local component=$2
	local relative_path backup

	while IFS= read -r relative_path; do
		[[ -n $relative_path ]] || continue
		if backup=$(mgs_state_find_backup "$target" "$component" "$relative_path"); then
			mkdir -p "$target/$(dirname -- "$relative_path")" || return
			cp -a "$backup" "$target/$relative_path" || return
		fi
	done < <(mgs_state_owned_files "$target" "$component")
}

mgs_state_prune_owned_dirs() {
	local target=$1
	local component=$2
	local relative_path directory

	while IFS= read -r directory; do
		[[ -n $directory && $directory != "." ]] || continue
		rmdir "$target/$directory" 2>/dev/null || true
	done < <(
		while IFS= read -r relative_path; do
			[[ $relative_path == */* ]] || continue
			dirname -- "$relative_path"
		done < <(mgs_state_owned_files "$target" "$component") |
			awk 'NF && !seen[$0]++' |
			awk '{ print length, $0 }' |
			sort -rn |
			cut -d' ' -f2-
	)
}

mgs_state_uninstall() {
	local target=$1
	local component=$2
	local dry_run=${3:-0}
	local relative_path manifest legacy state_dir

	if ! mgs_state_has_state "$target" "$component"; then
		return 3
	fi

	while IFS= read -r relative_path; do
		[[ -n $relative_path ]] || continue
		if (( dry_run )); then
			printf 'would remove %s\n' "$relative_path"
		else
			rm -f "$target/$relative_path"
		fi
	done < <(mgs_state_owned_files "$target" "$component")

	if (( dry_run )); then
		return 0
	fi

	mgs_state_restore_owned_backups "$target" "$component" || return
	mgs_state_prune_owned_dirs "$target" "$component"

	manifest=$(mgs_state_manifest "$target" "$component")
	legacy=$(mgs_state_legacy_manifest "$target" "$component")
	state_dir=$(mgs_state_dir "$target" "$component")
	rm -f "$manifest"
	[[ -n $legacy ]] && rm -f "$legacy"
	rm -rf "$state_dir"
	rmdir "$target/.mgs-installer" 2>/dev/null || true
}
