#!/usr/bin/env bash

# $1 = string
function strings::is_empty() {
  args::check_exactly_1_arg "$@"
  [[ -z "$1" ]]
}

# $1 = string
function strings::is_not_empty() {
  args::check_exactly_1_arg "$@"
  [[ -n "$1" ]]
}

# True if string is empty or contains only whitespace.
# $1 = string
function strings::is_blank() {
  args::check_exactly_1_arg "$@"
  [[ -z "${1//[[:space:]]/}" ]]
}

# $1 = string
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
