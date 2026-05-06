#!/usr/bin/env bash

# $1 = start seconds
# $2 = end seconds
function time::calc_elapsed() {
  args::check_exactly_2_args "$@"
  local elapsed=$(($2 - $1))
  readonly elapsed
  local hrs=$((elapsed / 3600))
  readonly hrs
  local mins=$(((elapsed - hrs * 3600) / 60))
  readonly mins
  local secs=$((elapsed - hrs * 3600 - mins * 60))
  readonly secs
  if [[ ${hrs} -gt 0 ]]; then
    printf '%s' "${hrs}h "
  fi
  if [[ ${mins} -gt 0 ]]; then
    printf '%s' "${mins}m "
  fi
  printf '%s\n' "${secs}s"
}

#shellcheck disable=SC2120
function time::shell_elapsed_time() {
  args::check_no_args "$@"
  time::calc_elapsed 0 "${SECONDS}"
}
