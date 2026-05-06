#!/usr/bin/env bash

# Print each element of an array on its own line.
# $@ = array elements to print
# Output: stdout — one element per line
function arrays::to_lines() {
  printf '%s\n' "$@"
}
