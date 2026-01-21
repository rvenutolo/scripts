#!/usr/bin/env bash

#shellcheck disable=SC2120
function reload_sysctl_conf() {
  check_no_args "$@"
  if prompt_yn 'Reload sysctl configuration?'; then
    log 'Reloading sysctl configuration'
    sudo sysctl --system --quiet
    log 'Reloaded sysctl configuration'
  fi
}
