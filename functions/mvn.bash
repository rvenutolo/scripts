#!/usr/bin/env bash

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
