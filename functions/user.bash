#!/usr/bin/env bash

#shellcheck disable=SC2120
function user::check_not_root() {
  args::check_no_args "$@"
  if [[ "${EUID}" == 0 ]]; then
    log::die "Must not be root"
  fi
}

#shellcheck disable=SC2120
function user::check_is_root() {
  args::check_no_args "$@"
  if [[ "${EUID}" != '0' ]]; then
    log::die 'Must be root'
  fi
}
