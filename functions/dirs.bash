#!/usr/bin/env bash

# Return true if the given path exists and is a directory.
# $1 = dir path
function dirs::exists() {
  args::check_exactly_1_arg "$@"
  [[ -d "$1" ]]
}

# Die if the given directory does not exist.
# $1 = dir path
function dirs::assert_exists() {
  args::check_exactly_1_arg "$@"
  local -r dir="$1"
  if ! dirs::exists "${dir}"; then
    log::die "${dir} does not exist"
  fi
}

# Create each given directory (and any missing parents) if it does not already exist.
# $@ = target directory paths
function dirs::create() {
  args::check_at_least_1_arg "$@"
  for target in "$@"; do
    if ! dirs::exists "${target}"; then
      log::log "Creating ${target}"
      mkdir --parents "${target}"
      log::log "Created ${target}"
    fi
  done
}

# Create each given directory (and any missing parents) as root if it does not already exist.
# $@ = target directory paths
function dirs::root_create() {
  args::check_at_least_1_arg "$@"
  for target in "$@"; do
    if ! dirs::exists "${target}"; then
      log::log "Creating ${target}"
      sudo mkdir --parents "${target}"
      log::log "Created ${target}"
    fi
  done
}
