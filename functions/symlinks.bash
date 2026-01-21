#!/usr/bin/env bash

# $1 = symlink
function symlink_exists() {
  check_exactly_1_arg "$@"
  [[ -L "$1" ]]
}

# $1 = symlink
function get_symlink_target() {
  if ! symlink_exists "$1"; then
    die "Symbolic link does not exist: $1"
  fi
  readlink "$1"
}
