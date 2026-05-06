#!/usr/bin/env bash

# $@ = array
function arrays::to_lines() {
  printf '%s\n' "$@"
}
