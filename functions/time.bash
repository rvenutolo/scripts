#!/usr/bin/env bash

# Print a human-readable elapsed time string (e.g. "1h 2m 3s") for a seconds interval.
# $1 = start time in seconds (e.g. from $SECONDS or date +%s)
# $2 = end time in seconds
# Output: stdout — elapsed time in "Xh Xm Xs" format (hours and minutes omitted when zero)
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

# Print the elapsed time since the current shell session started (using $SECONDS).
# Output: stdout — elapsed time in "Xh Xm Xs" format
#shellcheck disable=SC2120
function time::shell_elapsed_time() {
  args::check_no_args "$@"
  time::calc_elapsed 0 "${SECONDS}"
}
