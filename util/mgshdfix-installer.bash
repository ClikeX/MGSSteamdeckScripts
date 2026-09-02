#!/usr/bin/env bash

mgs_hdfix_acquire() {
	local workspace=$1
	local zip release_tag asset_name asset_url

	if [[ -n $MGS_CLI_ZIP ]]; then
		zip=$(mgs_installer_absolute_file "$MGS_CLI_ZIP") || return
		mgs_step "Using local MGSHDFix archive $(basename -- "$zip")"
	else
		mgs_step "Resolving MGSHDFix release"
		IFS=$'\t' read -r release_tag asset_name asset_url < <(
			mgs_installer_github_release ShizCalev/MGSHDFix MGSHDFix
		)
		[[ -n ${asset_url:-} ]] ||
			mgs_die "no MGSHDFix release asset was resolved"
		mgs_info "Release: $release_tag"
		mgs_info "Asset: $asset_name"
		zip=$workspace/mgshdfix.zip
		mgs_installer_download "$asset_url" "$zip"
	fi

	mgs_step "Validating and extracting MGSHDFix"
	MGS_HDFIX_SOURCE=$(
		mgs_installer_extract_archive "$zip" "$workspace/mgshdfix"
	) || return
}

mgs_hdfix_install() {
	local target=$1
	local dry_run=$2
	local -a hdfix_ini_paths=()
	local -a hdfix_stale_paths=(
		d3d11.dll
		MGSHDFix.asi
		"MGSHDFix Config Tool.exe"
	)

	mgs_payload_install "$target" "$MGS_HDFIX_SOURCE" mgshdfix 0 "$dry_run" \
		'(^|/)logs/|(^|/)MGSHDFix\.settings$' \
		'(^|/)MGSHDFix\.asi$' hdfix_ini_paths hdfix_stale_paths
}

mgs_hdfix_config_tool() {
	local source=$1
	local relative_path

	while IFS= read -r relative_path; do
		case "${relative_path,,}" in
			*config?tool*.exe)
				printf '%s\n' "$relative_path"
				return 0
				;;
		esac
	done < <(mgs_payload_files "$source" '(^|/)logs/')
	return 1
}
