#!/usr/bin/env bash

# Return true if the string is empty (zero length).
# $1 = string to test
function strings::is_empty() {
  args::check_exactly_1_arg "$@"
  [[ -z "$1" ]]
}

# Return true if the string is non-empty (at least one character).
# $1 = string to test
function strings::is_not_empty() {
  args::check_exactly_1_arg "$@"
  [[ -n "$1" ]]
}

# Return true if the string is empty or contains only whitespace characters.
# $1 = string to test
function strings::is_blank() {
  args::check_exactly_1_arg "$@"
  [[ -z "${1//[[:space:]]/}" ]]
}

# Print the string with a trailing slash appended if it does not already end with one.
# $1 = string
# Output: stdout — string guaranteed to end with '/'
function strings::ensure_trailing_slash() {
  args::check_exactly_1_arg "$@"
  if strings::is_not_empty "$1"; then
    case "$1" in
      */) printf '%s\n' "$1" ;;
      *) printf '%s\n' "$1/" ;;
    esac
  else
    printf '%s\n' "$1"
  fi
}
