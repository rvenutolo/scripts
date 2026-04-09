#!/usr/bin/env bash

# expected to pipe to this function: ex my_command | remove_ansi
#shellcheck disable=SC2120
function remove_ansi() {
  if stdin_exists; then
    check_no_args "$@"
    sed --regexp-extended "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g"
  else
    check_exactly_1_arg "$@"
    sed --regexp-extended "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" "$1"
  fi
}

#shellcheck disable=SC2120
function remove_empty_lines() {
  if stdin_exists; then
    check_no_args "$@"
    sed '/^[[:space:]]*$/d'
  else
    check_exactly_1_arg "$@"
    sed '/^[[:space:]]*$/d' "$1"
  fi
}

#shellcheck disable=SC2120
function first_line() {
  if stdin_exists; then
    check_no_args "$@"
    head --lines='1'
  else
    check_exactly_1_arg "$@"
    head --lines='1' "$1"
  fi
}

#shellcheck disable=SC2120
function last_line() {
  if stdin_exists; then
    check_no_args "$@"
    tail --lines='1'
  else
    check_exactly_1_arg "$@"
    tail --lines='1' "$1"
  fi
}

function skip_first_lines() {
  if stdin_exists; then
    check_exactly_1_arg "$@"
    local start_line=$(($1 + 1))
    tail --lines="+${start_line}"
  else
    check_exactly_2_arg "$@"
    local start_line=$(($2 + 1))
    tail --lines="+${start_line}" "$1"
  fi
}
