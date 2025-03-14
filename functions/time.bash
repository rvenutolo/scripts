#!/usr/bin/env bash

# $1 = start seconds
# $2 = end seconds
function calc_elapsed() {
  local elapsed=$(($2 - $1))
  local hrs=$((elapsed / 3600))
  local mins=$(((elapsed - hrs * 3600) / 60))
  local secs=$((elapsed - hrs * 3600 - mins * 60))
  if [[ ${hrs} -gt 0 ]]; then
    echo -n "${hrs}h "
  fi
  if [[ ${mins} -gt 0 ]]; then
    echo -n "${mins}m "
  fi
  echo "${secs}s"
}

function shell_elapsed_time() {
  calc_elapsed 0 $SECONDS
}
