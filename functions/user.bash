#!/usr/bin/env bash

#shellcheck disable=SC2120
function check_not_root() {
  check_no_args "$@"
  if [[ "${EUID}" == 0 ]]; then
    die "Must not be root"
  fi
}

#shellcheck disable=SC2120
function check_is_root() {
  check_no_args "$@"
  if [[ "${EUID}" != '0' ]]; then
    die 'Must be root'
  fi
}
