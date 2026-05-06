#!/usr/bin/env bash

# Return true if the current desktop environment name contains the given string (case-insensitive).
# $1 = desktop environment name fragment to match
function de::is_desktop_env() {
  args::check_exactly_1_arg "$@"
  printf '%s\n' "${XDG_CURRENT_DESKTOP:-}" | grep::contains_word_ignore_case "$1"
}

# Return true if the current desktop environment is KDE.
#shellcheck disable=SC2120
function de::is_kde() {
  args::check_no_args "$@"
  [[ "${XDG_CURRENT_DESKTOP:-}" == 'KDE' ]]
}

# Return true if the current desktop environment is GNOME.
#shellcheck disable=SC2120
function de::is_gnome() {
  args::check_no_args "$@"
  [[ "${XDG_CURRENT_DESKTOP:-}" == 'GNOME' ]] || [[ "${XDG_CURRENT_DESKTOP:-}" == 'ubuntu:GNOME' ]]
}

# Return true if the current desktop environment is Pop!_OS shell (pop:GNOME).
#shellcheck disable=SC2120
function de::is_pop_shell() {
  args::check_no_args "$@"
  [[ "${XDG_CURRENT_DESKTOP:-}" == 'pop:GNOME' ]]
}
