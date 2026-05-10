#!/usr/bin/env bash

# @description Die if the script is being run as root (EUID == 0).
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function user::check_not_root() {
  args::check_no_args "$@"
  if [[ "${EUID}" == '0' ]]; then
    log::die "Must not be root"
  fi
}

# @description Die if the script is not being run as root (EUID != 0).
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function user::check_is_root() {
  args::check_no_args "$@"
  if [[ "${EUID}" != '0' ]]; then
    log::die 'Must be root'
  fi
}
