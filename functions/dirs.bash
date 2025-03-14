#!/usr/bin/env bash

# $@ = targets
function create_dir() {
  check_at_least_1_arg "$@"
  for target in "$@"; do
    if [[ ! -d "${target}" ]]; then
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
    if [[ ! -d "${target}" ]]; then
      log "Creating ${target}"
      sudo mkdir --parents "${target}"
      log "Created ${target}"
    fi
  done
}
