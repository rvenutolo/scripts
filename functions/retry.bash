#!/usr/bin/env bash

# @description Retry a command with linear backoff. Sleeps base_sleep * attempt seconds between retries.
# Dies via log::die if the command does not succeed within max_tries attempts.
# @arg $1 max_tries (positive integer)
# @arg $2 base_sleep_seconds (positive integer; sleep grows linearly: base, base*2, base*3, ...)
# @arg $@ command and args to run (variadic, at least one)
# @exitcode 0 if the command succeeds within max_tries attempts
function retry::with_linear_backoff() {
  args::check_at_least_3_args "$@"
  local -r max_tries="$1"
  local -r base_sleep="$2"
  shift 2
  local tries=0
  until "$@"; do
    ((tries += 1)) || true
    if ((tries >= max_tries)); then
      log::die "Failed after ${max_tries} tries: $*"
    fi
    sleep "$((base_sleep * tries))"
  done
}

# @description Retry a command with exponential backoff. Sleeps base_sleep * 2^(attempt-1) seconds between retries.
# Dies via log::die if the command does not succeed within max_tries attempts.
# @arg $1 max_tries (positive integer)
# @arg $2 base_sleep_seconds (positive integer; sleep grows exponentially: base, base*2, base*4, ...)
# @arg $@ command and args to run (variadic, at least one)
# @exitcode 0 if the command succeeds within max_tries attempts
function retry::with_exponential_backoff() {
  args::check_at_least_3_args "$@"
  local -r max_tries="$1"
  local -r base_sleep="$2"
  shift 2
  local tries=0
  until "$@"; do
    ((tries += 1)) || true
    if ((tries >= max_tries)); then
      log::die "Failed after ${max_tries} tries: $*"
    fi
    sleep "$((base_sleep * (1 << (tries - 1))))"
  done
}
