#!/usr/bin/env bash

# $@ = variable names
function assert_var_set() {
  check_at_least_1_arg "$@"
  for var in "$@"; do
    if [[ -z "${!var:-}" ]]; then
      die "${var} not set"
    fi
  done
}
