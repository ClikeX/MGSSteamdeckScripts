#!/usr/bin/env bash

readonly MGS_IH_STAGE_DIR=InfiniteHeaven-staging
readonly MGS_IH_BACKUP_NAME=mgsv-ih-backup
readonly MGS_IH_NEXUS=https://www.nexusmods.com/metalgearsolidvtpp/mods/45
readonly MGS_IH_HOOK_NEXUS=https://www.nexusmods.com/metalgearsolidvtpp/mods/1226
readonly MGS_IH_SNAKEBITE_NEXUS=https://www.nexusmods.com/metalgearsolidvtpp/mods/106
readonly MGS_IH_WIKI=https://mgsvmoddingwiki.github.io/Infinite_Heaven/
readonly MGS_IH_DECK_WIKI=https://mgsvmoddingwiki.github.io/Steam_Deck/

mgs_ih_backup_root() {
	local target=$1
	local parent=${2-}

	if [[ -n $parent ]]; then
		printf '%s/%s\n' "${parent%/}" "$MGS_IH_BACKUP_NAME"
	else
		printf '%s/.%s\n' "$target" "$MGS_IH_BACKUP_NAME"
	fi
}

mgs_ih_file_size() {
	local size

	size=$(stat -c %s -- "$1" 2>/dev/null) ||
		size=$(stat -f %z -- "$1" 2>/dev/null) ||
		return 1
	[[ $size =~ ^[0-9]+$ ]] || return 1
	printf '%s\n' "$size"
}

mgs_ih_available_bytes() {
	df -Pk "$1" | awk 'NR == 2 { print $4 * 1024 }'
}

mgs_ih_backup() {
	local target=$1
	local backup_parent=${2-}
	local dry_run=$3
	local root probe parent relative source available total=0
	local timestamp saves_root steam_root userdata account_count=0
	local -a archives=(master/0/00.dat master/0/01.dat)

	root=$(mgs_ih_backup_root "$target" "$backup_parent")
	for relative in "${archives[@]}"; do
		source=$target/$relative
		[[ -f $source ]] ||
			mgs_die "missing $relative; this does not appear to be a complete MGS_TPP install"
		total=$((total + $(mgs_ih_file_size "$source")))
	done

	if [[ -e $root/00.dat || -e $root/01.dat ]]; then
		mgs_warn "presumed-vanilla archive backup already exists at $root"
		mgs_warn "it will not be overwritten with potentially modified archives"
	else
		probe=$root
		while [[ ! -d $probe ]]; do
			parent=$(dirname -- "$probe")
			[[ $parent != "$probe" ]] || break
			probe=$parent
		done
		[[ -d $probe ]] || mgs_die "cannot reach backup location $root"
		available=$(mgs_ih_available_bytes "$probe")
		(( available >= total + 104857600 )) ||
			mgs_die "not enough free space for the archive backup at $root"

		if (( dry_run )); then
			printf 'would create vanilla archive backup at %s\n' "$root"
		else
			mkdir -p "$root"
			for relative in "${archives[@]}"; do
				cp -p "$target/$relative" "$root/$(basename -- "$relative")"
			done
			date -u +%Y-%m-%dT%H:%M:%SZ > "$root/taken-at.txt"
		fi
	fi

	timestamp=$(date +%Y%m%d-%H%M%S)-$$
	saves_root=$root/saves-$timestamp
	while IFS= read -r steam_root; do
		for userdata in "$steam_root"/userdata/*/287700; do
			[[ -d $userdata ]] || continue
			account_count=$((account_count + 1))
			if (( dry_run )); then
				printf 'would back up saves %s\n' "$userdata"
			else
				mkdir -p "$saves_root"
				cp -a "$userdata" \
					"$saves_root/$(basename -- "$(dirname -- "$userdata")")-287700"
			fi
		done
	done < <(mgs_steam_roots)
	(( account_count )) ||
		mgs_warn "no Phantom Pain save directories were found under Steam userdata"
}

mgs_ih_stage() {
	local target=$1
	local dry_run=$2
	shift 2
	local archive absolute name destination package found

	for archive in "$@"; do
		absolute=$(mgs_installer_absolute_file "$archive") || return
		name=$(basename -- "$absolute")
		name=${name%.[Zz][Ii][Pp]}
		destination=$target/$MGS_IH_STAGE_DIR/$name
		if (( dry_run )); then
			printf 'would extract %s to %s\n' "$absolute" "$destination"
			continue
		fi
		"$MGS_UTIL_DIR/archive.py" extract "$absolute" "$destination" || return
		found=0
		while IFS= read -r package; do
			found=1
			printf 'staged package: %s\n' "${package#"$target"/}"
		done < <(find "$destination" -type f -iname '*.mgsv' | LC_ALL=C sort)
		(( found )) ||
			mgs_warn "no .mgsv package found in $(basename -- "$absolute")"
	done
}

mgs_ih_restore() {
	local target=$1
	local dry_run=$2
	local root relative timestamp
	local -a archives=(master/0/00.dat master/0/01.dat)

	root=$(mgs_ih_backup_root "$target")
	for relative in "${archives[@]}"; do
		[[ -f $root/$(basename -- "$relative") ]] ||
			mgs_die "no complete vanilla archive backup exists at $root"
	done

	if (( dry_run )); then
		for relative in "${archives[@]}"; do
			printf 'would restore %s\n' "$relative"
		done
	else
		for relative in "${archives[@]}"; do
			cp -p "$root/$(basename -- "$relative")" "$target/$relative"
		done
	fi

	if [[ -d $target/mod ]]; then
		if (( dry_run )); then
			printf 'would preserve mod/saves and remove mod/\n'
		else
			if [[ -d $target/mod/saves ]]; then
				timestamp=$(date +%Y%m%d-%H%M%S)-$$
				cp -a "$target/mod/saves" "$root/ih-saves-$timestamp"
			fi
			rm -rf "$target/mod"
		fi
	fi
	(( dry_run )) || rm -f "$target/Snakebite.xml"
}

mgs_ih_report() {
	local target=$1
	local backup_parent=${2-}
	local root prefix taken

	root=$(mgs_ih_backup_root "$target" "$backup_parent")
	printf '\nInfinite Heaven state\n'
	printf '  game folder: %s\n' "$target"
	[[ $(basename -- "$target") == MGS_TPP ]] ||
		mgs_warn "Infinite Heaven expects the game folder to be named MGS_TPP"

	if [[ -f $root/00.dat && -f $root/01.dat ]]; then
		taken=$(cat "$root/taken-at.txt" 2>/dev/null || printf unknown)
		printf '  vanilla archive backup: %s (%s)\n' "$root" "$taken"
	else
		printf '  vanilla archive backup: none\n'
	fi
	[[ -f $target/Snakebite.xml ]] &&
		printf '  Snakebite.xml: present\n' ||
		printf '  Snakebite.xml: absent\n'
	[[ -d $target/mod ]] &&
		printf '  mod/: present\n' ||
		printf '  mod/: absent\n'
	[[ -d $target/$MGS_IH_STAGE_DIR ]] &&
		printf '  staged packages: %s\n' "$target/$MGS_IH_STAGE_DIR"

	prefix=$(dirname -- "$(dirname -- "$target")")/compatdata/287700/pfx
	[[ -d $prefix ]] &&
		printf '  Proton prefix: %s\n' "$prefix" ||
		printf '  Proton prefix: not found; run the game once first\n'
	command -v protontricks >/dev/null 2>&1 &&
		printf '  Protontricks: installed\n' ||
		printf '  Protontricks: not installed\n'
}

mgs_ih_print_steps() {
	local target=$1
	local wine_path=${target//\//\\}

	cat <<EOF

Infinite Heaven cannot be installed headlessly. It is distributed through
Nexus Mods as a SnakeBite package, and SnakeBite has no command-line install
mode. The public source repository is not a release source.

Remaining steps:
1. Download Infinite Heaven:
   $MGS_IH_NEXUS
2. Download IHHook:
   $MGS_IH_HOOK_NEXUS
3. Download and install SnakeBite:
   $MGS_IH_SNAKEBITE_NEXUS
4. Stage both downloaded ZIPs with repeated --ih-zip options.
5. In SnakeBite, install each staged .mgsv package. Under Wine, browse to:
   Z:\\$wine_path\\$MGS_IH_STAGE_DIR

Steam Deck guide:
  $MGS_IH_DECK_WIKI
Infinite Heaven documentation:
  $MGS_IH_WIKI

Return to the ACC before installing or upgrading Infinite Heaven. Use
--ih-restore to restore the preserved vanilla archives and remove mod/ while
keeping a separate copy of mod/saves.
EOF
}
