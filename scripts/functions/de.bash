#!/usr/bin/env bash

# @description Return true if the current desktop environment name contains the given string (case-insensitive).
# @arg $1 desktop environment name fragment to match
# @exitcode 0 if true
# @exitcode 1 if false
function de::is_desktop_env() {
  args::check_exactly_1_arg "$@"
  printf '%s\n' "${XDG_CURRENT_DESKTOP:-}" | grep::contains_word_ignore_case "$1"
}

# @description Return true if the current desktop environment is KDE.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
# @exitcode 0 if true
# @exitcode 1 if false
function de::is_kde() {
  args::check_no_args "$@"
  [[ "${XDG_CURRENT_DESKTOP:-}" == 'KDE' ]]
}

# @description Return true if the current desktop environment is GNOME.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
# @exitcode 0 if true
# @exitcode 1 if false
function de::is_gnome() {
  args::check_no_args "$@"
  [[ "${XDG_CURRENT_DESKTOP:-}" == 'GNOME' ]] || [[ "${XDG_CURRENT_DESKTOP:-}" == 'ubuntu:GNOME' ]]
}

# @description Return true if the current desktop environment is Pop!_OS shell (pop:GNOME).
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
# @exitcode 0 if true
# @exitcode 1 if false
function de::is_pop_shell() {
  args::check_no_args "$@"
  [[ "${XDG_CURRENT_DESKTOP:-}" == 'pop:GNOME' ]]
}
