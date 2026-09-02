#!/usr/bin/env bash

if [[ -t 1 ]]; then
	MGS_COLOR_RED=$'\e[31m'
	MGS_COLOR_YELLOW=$'\e[33m'
	MGS_COLOR_GREEN=$'\e[32m'
	MGS_COLOR_DIM=$'\e[2m'
	MGS_COLOR_OFF=$'\e[0m'
else
	MGS_COLOR_RED=
	MGS_COLOR_YELLOW=
	MGS_COLOR_GREEN=
	MGS_COLOR_DIM=
	MGS_COLOR_OFF=
fi

mgs_info() {
	printf '%s\n' "$*"
}

mgs_step() {
	printf '%s==>%s %s\n' "$MGS_COLOR_GREEN" "$MGS_COLOR_OFF" "$*"
}

mgs_warn() {
	printf '%swarn:%s %s\n' "$MGS_COLOR_YELLOW" "$MGS_COLOR_OFF" "$*" >&2
}

mgs_error() {
	printf '%serror:%s %s\n' "$MGS_COLOR_RED" "$MGS_COLOR_OFF" "$*" >&2
}

mgs_die() {
	mgs_error "$*"
	exit 1
}

mgs_dim() {
	printf '%s%s%s\n' "$MGS_COLOR_DIM" "$*" "$MGS_COLOR_OFF"
}
