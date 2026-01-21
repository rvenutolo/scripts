#!/usr/bin/env bash

# expected to pipe to this function: ex my_command | remove_ansi
#shellcheck disable=SC2120
function remove_ansi() {
  check_no_args "$@"
  check_for_stdin
  sed --regexp-extended "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g"
}

# expected to pipe to this function, ex: my_command | remove_empty_lines
#shellcheck disable=SC2120
function remove_empty_lines() {
  check_no_args "$@"
  check_for_stdin
  sed '/^[[:space:]]*$/d'
}
