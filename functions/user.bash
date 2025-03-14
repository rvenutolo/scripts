#!/usr/bin/env bash

function check_not_root() {
  check_no_args "$@"
  if [[ "${EUID}" == 0 ]]; then
    die "Must not be root"
  fi
}

function check_is_root() {
  check_no_args "$@"
  if [[ "${EUID}" != '0' ]]; then
    die 'Must be root'
  fi
}
