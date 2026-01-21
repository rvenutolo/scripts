#!/usr/bin/env bash

# $1 = env
function is_desktop_env() {
  check_exactly_1_arg "$@"
  echo "${XDG_CURRENT_DESKTOP:-}" | contains_word_ignore_case "$1"
}

#shellcheck disable=SC2120
function is_kde() {
  check_no_args "$@"
  [[ "${XDG_CURRENT_DESKTOP:-}" == 'KDE' ]]
}

#shellcheck disable=SC2120
function is_gnome() {
  check_no_args "$@"
  [[ "${XDG_CURRENT_DESKTOP:-}" == 'GNOME' ]] || [[ "${XDG_CURRENT_DESKTOP:-}" == 'ubuntu:GNOME' ]]
}

#shellcheck disable=SC2120
function is_pop_shell() {
  check_no_args "$@"
  [[ "${XDG_CURRENT_DESKTOP:-}" == 'pop:GNOME' ]]
}
