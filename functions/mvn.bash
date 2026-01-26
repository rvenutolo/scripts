#!/usr/bin/env bash

function list_pom_files() {
  check_at_most_1_arg "$@"
  if [[ "$#" -eq 0 ]]; then
    readonly dir="."
  else
    readonly dir="$1"
  fi
  find "${dir}" -type 'd' \( ! -readable -o ! -executable \) -prune -o -name 'target' -prune -o -type 'f' -name 'pom.xml' -print | sort
}
