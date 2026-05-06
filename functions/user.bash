#!/usr/bin/env bash

# Die if the script is being run as root (EUID == 0).
#shellcheck disable=SC2120
function user::check_not_root() {
  args::check_no_args "$@"
  if [[ "${EUID}" == 0 ]]; then
    log::die "Must not be root"
  fi
}

# Die if the script is not being run as root (EUID != 0).
#shellcheck disable=SC2120
function user::check_is_root() {
  args::check_no_args "$@"
  if [[ "${EUID}" != '0' ]]; then
    log::die 'Must be root'
  fi
}
