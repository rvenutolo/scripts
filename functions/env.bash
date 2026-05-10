#!/usr/bin/env bash

# @description Die if any of the named environment variables is unset or empty.
# @arg $@ variable names to check
function env::assert_var_set() {
  args::check_at_least_1_arg "$@"
  for var in "$@"; do
    if strings::is_empty "${!var:-}"; then
      log::die "${var} not set"
    fi
  done
}
