#!/usr/bin/env bash

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
