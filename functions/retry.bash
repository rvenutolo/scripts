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

# @description Retry a command indefinitely until it succeeds, with no sleep between attempts.
# Intended for interactive prompts (e.g. passphrase entry) where the user reacts immediately to
# failure and backoff would only add friction. No max-attempt cap — the caller's command must
# provide its own escape hatch (e.g. SIGINT) if the operation should not be retried forever.
# @arg $@ command and args to run (variadic, at least one)
# @exitcode 0 once the command succeeds
function retry::until_success() {
  args::check_at_least_1_arg "$@"
  until "$@"; do :; done
}

# @description Poll a command at a constant interval until it succeeds or a wall-clock deadline passes.
# Unlike the backoff variants (which cap by attempt count and grow the sleep), this caps by elapsed
# wall-clock time and keeps the sleep fixed at interval_seconds. Elapsed time is measured via the bash
# SECONDS builtin against a start offset captured at entry. Dies via log::die if the command does not
# succeed before timeout_seconds elapse.
# @arg $1 timeout_seconds (positive integer; wall-clock deadline)
# @arg $2 interval_seconds (positive integer; constant sleep between attempts)
# @arg $@ command and args to run (variadic, at least one)
# @exitcode 0 if the command succeeds before the deadline
function retry::until_deadline() {
  args::check_at_least_3_args "$@"
  local -r timeout="$1"
  local -r interval="$2"
  shift 2
  local -r start="${SECONDS}"
  while true; do
    if "$@"; then
      return 0
    fi
    if ((SECONDS - start >= timeout)); then
      log::die "Timed out after ${timeout}s waiting for: $*"
    fi
    sleep "${interval}"
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
