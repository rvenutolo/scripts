#!/usr/bin/env bash

# @description Print each element of an array on its own line.
# Output: stdout — one element per line
# @arg $@ array elements to print
function arrays::to_lines() {
  printf '%s\n' "$@"
}
