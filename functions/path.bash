#!/usr/bin/env bash

# $1 = path to remove
function path_remove() {
  check_exactly_1_arg "$@"
  PATH=$(echo -n "$PATH" | awk -v 'RS=:' -v 'ORS=:' '$0 != "'"$1"'"' | sed 's/:$//') || exit 1
}

# $1 = path to append
function path_append() {
  check_exactly_1_arg "$@"
  path_remove "$1" && PATH="$PATH:$1"
}

# $1 = path to prepend
function path_prepend() {
  check_exactly_1_arg "$@"
  path_remove "$1" && PATH="$1:$PATH"
}
