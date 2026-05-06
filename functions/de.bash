#!/usr/bin/env bash

# $1 = env
function de::is_desktop_env() {
  args::check_exactly_1_arg "$@"
  printf '%s\n' "${XDG_CURRENT_DESKTOP:-}" | grep::contains_word_ignore_case "$1"
}

#shellcheck disable=SC2120
function de::is_kde() {
  args::check_no_args "$@"
  [[ "${XDG_CURRENT_DESKTOP:-}" == 'KDE' ]]
}

#shellcheck disable=SC2120
function de::is_gnome() {
  args::check_no_args "$@"
  [[ "${XDG_CURRENT_DESKTOP:-}" == 'GNOME' ]] || [[ "${XDG_CURRENT_DESKTOP:-}" == 'ubuntu:GNOME' ]]
}

#shellcheck disable=SC2120
function de::is_pop_shell() {
  args::check_no_args "$@"
  [[ "${XDG_CURRENT_DESKTOP:-}" == 'pop:GNOME' ]]
}
