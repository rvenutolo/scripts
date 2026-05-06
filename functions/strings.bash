#!/usr/bin/env bash

# $1 = string
function is_empty() {
  check_exactly_1_arg "$@"
  [[ -z "$1" ]]
}

# $1 = string
function is_not_empty() {
  check_exactly_1_arg "$@"
  [[ -n "$1" ]]
}

# True if string is empty or contains only whitespace.
# $1 = string
function is_blank() {
  check_exactly_1_arg "$@"
  [[ -z "${1//[[:space:]]/}" ]]
}

# $1 = string
function ensure_trailing_slash() {
  check_exactly_1_arg "$@"
  if is_not_empty "$1"; then
    case "$1" in
      */) printf '%s\n' "$1" ;;
      *) printf '%s\n' "$1/" ;;
    esac
  else
    printf '%s\n' "$1"
  fi
}
