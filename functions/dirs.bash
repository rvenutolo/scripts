#!/usr/bin/env bash

# $1 = dir
function dirs::exists() {
  args::check_exactly_1_arg "$@"
  [[ -d "$1" ]]
}

# $1 = dir
function dirs::assert_exists() {
  args::check_exactly_1_arg "$@"
  if ! dirs::exists "$1"; then
    log::die "$1 does not exist"
  fi
}

# $@ = targets
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

# $@ = targets
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
