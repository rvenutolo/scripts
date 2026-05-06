#!/usr/bin/env bash

# Sort JSON keys recursively. Reads from stdin or a file argument.
# $1 = JSON file path (optional; reads stdin if omitted)
# Output: stdout — JSON with all object keys sorted
function json::sort() {
  if args::stdin_exists; then
    args::check_no_args "$@"
    jq --sort-keys '.'
  else
    args::check_exactly_1_arg "$@"
    jq --sort-keys '.' "$1"
  fi
}
