#!/usr/bin/env bash

# path_remove "$(this_script_dir)"
#shellcheck disable=SC2120
function this_script_dir() {
  check_no_args "$@"
  cd -- "$(dirname -- "${BASH_SOURCE[1]}")" &> '/dev/null' && pwd
}

#shellcheck disable=SC2120
function auto_answer() {
  check_no_args "$@"
  [[ "${SCRIPTS_AUTO_ANSWER:-}" == [Yy] ]]
}
