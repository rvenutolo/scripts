#!/usr/bin/env bash

# Strip ANSI escape sequences from stdin or a file.
# $1 = file path (optional; reads stdin if omitted)
# Output: stdout — text with ANSI codes removed
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

# Remove blank lines (empty or whitespace-only) from stdin or a file.
# $1 = file path (optional; reads stdin if omitted)
# Output: stdout — text with blank lines removed
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

# Print the first line of stdin or a file.
# $1 = file path (optional; reads stdin if omitted)
# Output: stdout — first line of input
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

# Print the last line of stdin or a file.
# $1 = file path (optional; reads stdin if omitted)
# Output: stdout — last line of input
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

# Print all lines after the first N lines of stdin or a file.
# With stdin: $1 = number of lines to skip.
# With file:  $1 = file path, $2 = number of lines to skip.
# Output: stdout — remaining lines after the skipped prefix
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
