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
