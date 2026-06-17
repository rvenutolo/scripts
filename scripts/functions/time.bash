#!/usr/bin/env bash

# @description Print a human-readable elapsed time string (e.g. "1h 2m 3s") for a seconds interval.
# Output: stdout — elapsed time in "Xh Xm Xs" format (hours and minutes omitted when zero)
# @arg $1 start time in seconds (e.g. from $SECONDS or date +%s)
# @arg $2 end time in seconds
function time::calc_elapsed() {
  args::check_exactly_2_args "$@"
  local -r start_time="$1"
  local -r end_time="$2"
  if ((10#${end_time} < 10#${start_time})); then
    log::die 'end_time must be >= start_time'
  fi
  local elapsed=$((10#${end_time} - 10#${start_time}))
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

# @description Print the elapsed time since the current shell session started (using $SECONDS).
# Output: stdout — elapsed time in "Xh Xm Xs" format
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function time::shell_elapsed_time() {
  args::check_no_args "$@"
  time::calc_elapsed 0 "${SECONDS}"
}
