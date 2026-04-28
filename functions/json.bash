#!/usr/bin/env bash

function sort_json() {
  if stdin_exists; then
    check_no_args "$@"
    jq --sort-keys '.'
  else
    check_exactly_1_arg "$@"
    jq --sort-keys '.' "$1"
  fi
}
