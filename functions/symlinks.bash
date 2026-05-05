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

# $1 = target file
# $2 = link file
function link_file() {
  check_exactly_2_args "$@"
  assert_file_exists "$1"
  if [[ -L "$2" && "$(readlink --canonicalize "$2")" == "$(readlink --canonicalize "$1")" ]]; then
    return 0
  fi
  if file_exists "$2"; then
    diff --color --unified "$2" "$1" || true
    if ! prompt_yn "$2 exists - Link: $1 -> $2?"; then
      return 0
    fi
  else
    if ! prompt_yn "Link: $1 -> $2?"; then
      return 0
    fi
  fi
  log "Linking: $1 -> $2"
  create_dir "$(dirname "$2")"
  ln --symbolic --force "$1" "$2"
  log "Linked: $1 -> $2"
}

# $1 = target directory
# $2 = link path
function link_dir() {
  check_exactly_2_args "$@"
  assert_dir_exists "$1"
  if [[ -L "$2" && "$(readlink --canonicalize "$2")" == "$(readlink --canonicalize "$1")" ]]; then
    return 0
  fi
  if dir_exists "$2"; then
    if ! prompt_yn "$2 exists - Link: $1 -> $2?"; then
      return 0
    fi
  else
    if ! prompt_yn "Link: $1 -> $2?"; then
      return 0
    fi
  fi
  log "Linking: $1 -> $2"
  create_dir "$(dirname "$2")"
  ln --symbolic --force "$1" "$2"
  log "Linked: $1 -> $2"
}
