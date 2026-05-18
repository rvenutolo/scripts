#!/usr/bin/env bash

# @description Strip ANSI escape sequences from stdin or a file.
# Output: stdout — text with ANSI codes removed
# expected to pipe to this function: ex my_command | text::remove_ansi
# @arg $1 file path (optional; reads stdin if omitted)
function text::remove_ansi() {
  if args::has_at_least_num_args 1 "$@"; then
    args::check_exactly_1_arg "$@"
    sed --regexp-extended "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" "$1"
  else
    args::check_for_stdin
    sed --regexp-extended "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g"
  fi
}

# @description Remove blank lines (empty or whitespace-only) from stdin or a file.
# Output: stdout — text with blank lines removed
# @arg $1 file path (optional; reads stdin if omitted)
function text::remove_empty_lines() {
  if args::has_at_least_num_args 1 "$@"; then
    args::check_exactly_1_arg "$@"
    sed '/^[[:space:]]*$/d' "$1"
  else
    args::check_for_stdin
    sed '/^[[:space:]]*$/d'
  fi
}

# @description Print the first line of stdin or a file.
# Output: stdout — first line of input
# @arg $1 file path (optional; reads stdin if omitted)
function text::first_line() {
  if args::has_at_least_num_args 1 "$@"; then
    args::check_exactly_1_arg "$@"
    head --lines=1 "$1"
  else
    args::check_for_stdin
    head --lines=1
  fi
}

# @description Print the last line of stdin or a file.
# Output: stdout — last line of input
# @arg $1 file path (optional; reads stdin if omitted)
function text::last_line() {
  if args::has_at_least_num_args 1 "$@"; then
    args::check_exactly_1_arg "$@"
    tail --lines=1 "$1"
  else
    args::check_for_stdin
    tail --lines=1
  fi
}

# @description Print all lines after the first N lines of stdin or a file.
# With stdin: $1 = number of lines to skip.
# With file:  $1 = file path, $2 = number of lines to skip.
# Output: stdout — remaining lines after the skipped prefix
# @noargs
function text::skip_first_lines() {
  if args::has_at_least_num_args 2 "$@"; then
    args::check_exactly_2_args "$@"
    local -r file="$1"
    local -r skip_count="$2"
    local start_line
    start_line=$((skip_count + 1))
    tail --lines="+${start_line}" "${file}"
  else
    args::check_exactly_1_arg "$@"
    local -r skip_count="$1"
    local start_line
    start_line=$((skip_count + 1))
    tail --lines="+${start_line}"
  fi
}
