#!/usr/bin/env bash

# These functions intentionally mutate the caller's PATH (they do NOT scope mutations to a subshell).
# Callers that want PATH changes confined to a block must wrap the call in their own ( ... ) subshell.

# Remove all occurrences of a directory from PATH.
# $1 = directory path to remove
function path::remove() {
  args::check_exactly_1_arg "$@"
  PATH="$(
    printf '%s' "${PATH}" \
      | awk --assign 'RS=:' --assign 'ORS=:' --assign "path=$1" '$0 != path' \
      | sed 's/:$//'
  )"
}

# Append a directory to PATH (removing any existing occurrence first to avoid duplicates).
# $1 = directory path to append
function path::append() {
  args::check_exactly_1_arg "$@"
  path::remove "$1" && PATH="${PATH}:$1"
}

# Prepend a directory to PATH (removing any existing occurrence first to avoid duplicates).
# $1 = directory path to prepend
function path::prepend() {
  args::check_exactly_1_arg "$@"
  path::remove "$1" && PATH="$1:${PATH}"
}
