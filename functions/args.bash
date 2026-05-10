#!/usr/bin/env bash

# @description Die if called with any arguments.
# @arg $@ caller's arguments (count-checked; 0 expected)
function args::check_no_args() {
  if [[ "$#" -ne 0 ]]; then
    log::die 'Expected no arguments'
  fi
}

# @description Die if called with more than 1 argument.
# @arg $@ caller's arguments (count-checked; ≤1 expected)
function args::check_at_most_1_arg() {
  if [[ "$#" -gt 1 ]]; then
    log::die 'Expected at most 1 argument'
  fi
}

# @description Die if not called with exactly 1 argument.
# @arg $@ caller's arguments (count-checked; exactly 1 expected)
function args::check_exactly_1_arg() {
  if [[ "$#" -ne 1 ]]; then
    log::die 'Expected exactly 1 argument'
  fi
}

# @description Die if called with fewer than 1 argument.
# @arg $@ caller's arguments (count-checked; ≥1 expected)
function args::check_at_least_1_arg() {
  if [[ "$#" -lt 1 ]]; then
    log::die 'Expected at least 1 argument'
  fi
}

# @description Die if called with more than 2 arguments.
# @arg $@ caller's arguments (count-checked; ≤2 expected)
function args::check_at_most_2_args() {
  if [[ "$#" -gt 2 ]]; then
    log::die 'Expected at most 2 arguments'
  fi
}

# @description Die if not called with exactly 2 arguments.
# @arg $@ caller's arguments (count-checked; exactly 2 expected)
function args::check_exactly_2_args() {
  if [[ "$#" -ne 2 ]]; then
    log::die 'Expected exactly 2 arguments'
  fi
}

# @description Die if called with fewer than 2 arguments.
# @arg $@ caller's arguments (count-checked; ≥2 expected)
function args::check_at_least_2_args() {
  if [[ "$#" -lt 2 ]]; then
    log::die 'Expected at least 2 arguments'
  fi
}

# @description Die if called with more than 3 arguments.
# @arg $@ caller's arguments (count-checked; ≤3 expected)
function args::check_at_most_3_args() {
  if [[ "$#" -gt 3 ]]; then
    log::die 'Expected at most 3 arguments'
  fi
}

# @description Die if not called with exactly 3 arguments.
# @arg $@ caller's arguments (count-checked; exactly 3 expected)
function args::check_exactly_3_args() {
  if [[ "$#" -ne 3 ]]; then
    log::die 'Expected exactly 3 arguments'
  fi
}

# @description Die if called with fewer than 3 arguments.
# @arg $@ caller's arguments (count-checked; ≥3 expected)
function args::check_at_least_3_args() {
  if [[ "$#" -lt 3 ]]; then
    log::die 'Expected at least 3 arguments'
  fi
}

# @description Die if called with more than 4 arguments.
# @arg $@ caller's arguments (count-checked; ≤4 expected)
function args::check_at_most_4_args() {
  if [[ "$#" -gt 4 ]]; then
    log::die 'Expected at most 4 arguments'
  fi
}

# @description Die if not called with exactly 4 arguments.
# @arg $@ caller's arguments (count-checked; exactly 4 expected)
function args::check_exactly_4_args() {
  if [[ "$#" -ne 4 ]]; then
    log::die 'Expected exactly 4 arguments'
  fi
}

# @description Die if called with fewer than 4 arguments.
# @arg $@ caller's arguments (count-checked; ≥4 expected)
function args::check_at_least_4_args() {
  if [[ "$#" -lt 4 ]]; then
    log::die 'Expected at least 4 arguments'
  fi
}

# @description Die if stdin has no data available (i.e., a terminal is attached).
# shellcheck disable=SC2120 # called with no args by callers, but shellcheck can't see all call sites
# @noargs
function args::check_for_stdin() {
  args::check_no_args "$@"
  if [[ -t 0 ]]; then
    log::die 'Expected STDIN'
  fi
}

# @description Return true if stdin has data available (i.e., not a terminal).
# shellcheck disable=SC2120 # called with no args by callers, but shellcheck can't see all call sites
# @noargs
# @exitcode 0 if true
# @exitcode 1 if false
function args::stdin_exists() {
  args::check_no_args "$@"
  ! [[ -t 0 ]]
}
