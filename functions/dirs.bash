#!/usr/bin/env bash

# @description Return true if the given path exists and is a directory.
# @arg $1 dir path
function dirs::exists() {
  args::check_exactly_1_arg "$@"
  [[ -d "$1" ]]
}

# @description Die if the given directory does not exist.
# @arg $1 dir path
function dirs::assert_exists() {
  args::check_exactly_1_arg "$@"
  local -r dir="$1"
  if ! dirs::exists "${dir}"; then
    log::die "${dir} does not exist"
  fi
}

# @description Create each given directory (and any missing parents) if it does not already exist.
# @arg $@ target directory paths
function dirs::create() {
  args::check_at_least_1_arg "$@"
  for dir in "$@"; do
    if ! dirs::exists "${dir}"; then
      log::log "Creating ${dir}"
      mkdir --parents "${dir}"
      log::log "Created ${dir}"
    fi
  done
}

# @description Create each given directory (and any missing parents) as root if it does not already exist.
# @arg $@ target directory paths
function dirs::root_create() {
  args::check_at_least_1_arg "$@"
  for dir in "$@"; do
    if ! dirs::exists "${dir}"; then
      log::log "Creating ${dir}"
      sudo mkdir --parents "${dir}"
      log::log "Created ${dir}"
    fi
  done
}
