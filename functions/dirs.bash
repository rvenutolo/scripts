#!/usr/bin/env bash

# $1 = dir
function dir_exists() {
  check_exactly_1_arg "$@"
  [[ -d "$1" ]]
}

# $@ = targets
function create_dir() {
  check_at_least_1_arg "$@"
  for target in "$@"; do
    if ! dir_exists "${target}"; then
      log "Creating ${target}"
      mkdir --parents "${target}"
      log "Created ${target}"
    fi
  done
}

# $@ = targets
function root_create_dir() {
  check_at_least_1_arg "$@"
  for target in "$@"; do
    if ! dir_exists "${target}"; then
      log "Creating ${target}"
      sudo mkdir --parents "${target}"
      log "Created ${target}"
    fi
  done
}
