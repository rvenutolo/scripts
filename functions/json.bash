#!/usr/bin/env bash

function json::sort() {
  if args::stdin_exists; then
    args::check_no_args "$@"
    jq --sort-keys '.'
  else
    args::check_exactly_1_arg "$@"
    jq --sort-keys '.' "$1"
  fi
}
