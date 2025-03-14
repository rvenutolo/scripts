#!/usr/bin/env bash

# $1 = file
function file_exists() {
  check_exactly_1_arg "$@"
  [[ -f "$1" ]]
}

# $1 = file
function is_readable_file() {
  check_exactly_1_arg "$@"
  [[ -r "$1" ]]
}

# $1 = file
function file_size_gb() {
  echo "scale=2; $(stat --format='%s' "$1") / 1073741824" | bc
}

# $1 = target file
# $2 = link file
function link_user_file() {
  check_not_root
  check_exactly_2_args "$@"
  if [[ ! -f "$1" ]]; then
    die "$1 does not exist"
  fi
  if [[ -L "$2" && "$(readlink --canonicalize "$2")" == "$(readlink --canonicalize "$1")" ]]; then
    exit 0
  fi
  if [[ -f "$2" ]]; then
    diff --color --unified "$2" "$1" || true
    if ! prompt_yn "$2 exists - Link: $1 -> $2?"; then
      exit 0
    fi
  else
    if ! prompt_yn "Link: $1 -> $2?"; then
      exit 0
    fi
  fi
  log "Linking: $1 -> $2"
  mkdir --parents "$(dirname "$2")"
  ln --symbolic --force "$1" "$2"
  log "Linked: $1 -> $2"
}

# $1 = old file location
# $2 = new file location
function move_user_file() {
  check_not_root
  check_exactly_2_args "$@"
  if [[ ! -f "$1" ]]; then
    die "$1 does not exist"
  fi
  if [[ "$1" == "$2" ]]; then
    die "File paths are the same"
  fi
  if [[ -f "$2" ]]; then
    diff --color --unified "$2" "$1" || true
    if ! prompt_yn "$2 exists - Overwrite: $1 -> $2?"; then
      exit 0
    fi
  else
    if ! prompt_yn "Move $1 -> $2?"; then
      exit 0
    fi
  fi
  log "Moving: $1 -> $2"
  mkdir --parents "$(dirname "$2")"
  mv "$1" "$2"
  log "Moved: $1 -> $2"
}

# $1 = old file location
# $2 = new file location
function copy_user_file() {
  check_not_root
  check_exactly_2_args "$@"
  if [[ ! -f "$1" ]]; then
    die "$1 does not exist"
  fi
  if [[ "$1" == "$2" ]]; then
    die "File paths are the same"
  fi
  if [[ -f "$2" ]]; then
    if cmp --silent "$1" "$2"; then
      exit 0
    else
      diff --color --unified "$2" "$1" || true
      if ! prompt_yn "$2 exists - Overwrite: $1 -> $2?"; then
        exit 0
      fi
    fi
  else
    if ! prompt_yn "Copy $1 -> $2?"; then
      exit 0
    fi
  fi
  log "Copying: $1 -> $2"
  mkdir --parents "$(dirname "$2")"
  cp "$1" "$2"
  log "Copied: $1 -> $2"
}

# $1 = source file
# $2 = destination file
function copy_system_file() {
  check_exactly_2_args "$@"
  if [[ ! -f "$1" ]]; then
    die "$1 does not exist"
  fi
  if [[ "$1" == "$2" ]]; then
    die "File paths are the same"
  fi
  if sudo bash -c "[[ -f $2 ]]"; then
    if sudo cmp --silent "$1" "$2"; then
      exit 0
    else
      sudo diff --color --unified "$2" "$1" || true
      if ! prompt_yn "$2 exists - Overwrite: $1 -> $2?"; then
        exit 0
      fi
    fi
  else
    if ! prompt_yn "Copy $1 -> $2?"; then
      exit 0
    fi
  fi
  log "Copying: $1 -> $2"
  sudo mkdir --parents "$(dirname "$2")"
  sudo cp "$1" "$2"
  log "Copied: $1 -> $2"
}
