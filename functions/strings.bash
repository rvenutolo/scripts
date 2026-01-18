#!/usr/bin/env bash

# $1 = string
function ensure_trailing_slash() {
  check_exactly_1_arg "$@"
  if [[ -n "$1" ]]; then
    case "$1" in
      */) echo "$1" ;;
      *) echo "$1/" ;;
    esac
  else
    echo "$1"
  fi
}

# expected to pipe to this function: ex my_command | remove_ansi
function remove_ansi() {
  check_no_args "$@"
  check_for_stdin
  sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g"
}

# expected to pipe to this function, ex: my_command | remove_empty_lines
function remove_empty_lines() {
  check_no_args "$@"
  check_for_stdin
  sed '/^[[:space:]]*$/d'
}
