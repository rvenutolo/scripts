#!/usr/bin/env bash

# Find and print all pom.xml file paths under a directory, excluding target/ trees.
# $1 = root directory to search (optional; defaults to current directory)
# Output: stdout — sorted list of pom.xml paths, one per line
function mvn::list_pom_files() {
  args::check_at_most_1_arg "$@"
  if [[ "$#" -eq 0 ]]; then
    local -r dir="."
  else
    local -r dir="$1"
  fi
  find "${dir}" \
    -type 'd' \( ! -readable -o ! -executable \) -prune \
    -o -name 'target' -prune \
    -o -type 'f' -name 'pom.xml' -print \
    | sort
}
