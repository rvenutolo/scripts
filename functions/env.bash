#!/usr/bin/env bash

# $@ = variable names
function env::assert_var_set() {
  args::check_at_least_1_arg "$@"
  for var in "$@"; do
    if strings::is_empty "${!var:-}"; then
      log::die "${var} not set"
    fi
  done
}
