#!/usr/bin/env bash

# $1 = path to remove
function path::remove() {
  args::check_exactly_1_arg "$@"
  PATH="$(
    printf '%s' "${PATH}" \
      | awk --assign 'RS=:' --assign 'ORS=:' --assign "path=$1" '$0 != path' \
      | sed 's/:$//'
  )" || exit 1
}

# $1 = path to append
function path::append() {
  args::check_exactly_1_arg "$@"
  path::remove "$1" && PATH="${PATH}:$1"
}

# $1 = path to prepend
function path::prepend() {
  args::check_exactly_1_arg "$@"
  path::remove "$1" && PATH="$1:${PATH}"
}
