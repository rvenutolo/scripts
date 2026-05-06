#!/usr/bin/env bash

# $1 = symlink
function symlinks::exists() {
  args::check_exactly_1_arg "$@"
  [[ -L "$1" ]]
}

# $1 = symlink
function symlinks::get_target() {
  if ! symlinks::exists "$1"; then
    log::die "Symbolic link does not exist: $1"
  fi
  readlink "$1"
}

# $1 = target file
# $2 = link file
function symlinks::link_file() {
  args::check_exactly_2_args "$@"
  files::assert_exists "$1"
  if [[ -L "$2" && "$(readlink --canonicalize "$2")" == "$(readlink --canonicalize "$1")" ]]; then
    return 0
  fi
  if files::exists "$2"; then
    diff --color --unified "$2" "$1" || true
    if ! prompt::yn "$2 exists - Link: $1 -> $2?"; then
      return 0
    fi
  else
    if ! prompt::yn "Link: $1 -> $2?"; then
      return 0
    fi
  fi
  log::log "Linking: $1 -> $2"
  dirs::create "$(dirname "$2")"
  ln --symbolic --force "$1" "$2"
  log::log "Linked: $1 -> $2"
}

# $1 = target directory
# $2 = link path
function symlinks::link_dir() {
  args::check_exactly_2_args "$@"
  dirs::assert_exists "$1"
  if [[ -L "$2" && "$(readlink --canonicalize "$2")" == "$(readlink --canonicalize "$1")" ]]; then
    return 0
  fi
  if dirs::exists "$2"; then
    if ! prompt::yn "$2 exists - Link: $1 -> $2?"; then
      return 0
    fi
  else
    if ! prompt::yn "Link: $1 -> $2?"; then
      return 0
    fi
  fi
  log::log "Linking: $1 -> $2"
  dirs::create "$(dirname "$2")"
  ln --symbolic --force "$1" "$2"
  log::log "Linked: $1 -> $2"
}
