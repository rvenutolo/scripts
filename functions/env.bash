#!/usr/bin/env bash

# $1 = variable name
function check_env_var_set() {
  check_exactly_1_arg "$@"
  if [[ -z "${!1:-}" ]]; then
    die "$1 not set"
  fi
}
