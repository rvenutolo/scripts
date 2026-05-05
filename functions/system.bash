#!/usr/bin/env bash

# $1 = required major version (e.g. 4)
# $2 = required minor version (e.g. 3)
function require_bash_version() {
  check_exactly_2_args "$@"
  local -r req_major="$1"
  local -r req_minor="$2"
  if ((BASH_VERSINFO[0] < req_major)) \
    || ((BASH_VERSINFO[0] == req_major && BASH_VERSINFO[1] < req_minor)); then
    die "bash ${req_major}.${req_minor}+ required (current: ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]})"
  fi
}

#shellcheck disable=SC2120
function reload_sysctl_conf() {
  check_no_args "$@"
  if prompt_yn 'Reload sysctl configuration?'; then
    log 'Reloading sysctl configuration'
    sudo sysctl --system --quiet
    log 'Reloaded sysctl configuration'
  fi
}
