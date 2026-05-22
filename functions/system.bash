#!/usr/bin/env bash

# @description Die if the running bash version is older than the required major.minor version.
# @arg $1 required major version (e.g. 4)
# @arg $2 required minor version (e.g. 3)
function system::require_bash_version() {
  args::check_exactly_2_args "$@"
  local -r req_major="$1"
  local -r req_minor="$2"
  if ((BASH_VERSINFO[0] < req_major)) ||
    ((BASH_VERSINFO[0] == req_major && BASH_VERSINFO[1] < req_minor)); then
    log::die "bash ${req_major}.${req_minor}+ required (current: ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]})"
  fi
}

# @description Prompt and then reload sysctl configuration via 'sudo sysctl --system'.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function system::reload_sysctl_conf() {
  args::check_no_args "$@"
  if prompt::yn 'Reload sysctl configuration?'; then
    log::log 'Reloading sysctl configuration'
    sudo sysctl --system --quiet
    log::log 'Reloaded sysctl configuration'
  fi
}
