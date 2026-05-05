#!/usr/bin/env bash

# $1 = string
function ensure_trailing_slash() {
  check_exactly_1_arg "$@"
  if [[ -n "$1" ]]; then
    case "$1" in
      */) printf '%s\n' "$1" ;;
      *) printf '%s\n' "$1/" ;;
    esac
  else
    printf '%s\n' "$1"
  fi
}
