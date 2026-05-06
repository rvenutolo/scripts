#!/usr/bin/env bash

# expected to pipe to this function: ex my_command | text::remove_ansi
#shellcheck disable=SC2120
function text::remove_ansi() {
  if args::stdin_exists; then
    args::check_no_args "$@"
    sed --regexp-extended "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g"
  else
    args::check_exactly_1_arg "$@"
    sed --regexp-extended "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" "$1"
  fi
}

#shellcheck disable=SC2120
function text::remove_empty_lines() {
  if args::stdin_exists; then
    args::check_no_args "$@"
    sed '/^[[:space:]]*$/d'
  else
    args::check_exactly_1_arg "$@"
    sed '/^[[:space:]]*$/d' "$1"
  fi
}

#shellcheck disable=SC2120
function text::first_line() {
  if args::stdin_exists; then
    args::check_no_args "$@"
    head --lines=1
  else
    args::check_exactly_1_arg "$@"
    head --lines=1 "$1"
  fi
}

#shellcheck disable=SC2120
function text::last_line() {
  if args::stdin_exists; then
    args::check_no_args "$@"
    tail --lines=1
  else
    args::check_exactly_1_arg "$@"
    tail --lines=1 "$1"
  fi
}

function text::skip_first_lines() {
  if args::stdin_exists; then
    args::check_exactly_1_arg "$@"
    local start_line=$(($1 + 1))
    tail --lines="+${start_line}"
  else
    args::check_exactly_2_args "$@"
    local start_line=$(($2 + 1))
    tail --lines="+${start_line}" "$1"
  fi
}
