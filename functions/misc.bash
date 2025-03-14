#!/usr/bin/env bash

# path_remove "$(this_script_dir)"
function this_script_dir() {
  check_no_args "$@"
  cd -- "$(dirname -- "${BASH_SOURCE[1]}")" &> '/dev/null' && pwd
}

function auto_answer() {
  [[ "${SCRIPTS_AUTO_ANSWER:-}" == [Yy] ]]
}
