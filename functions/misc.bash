#!/usr/bin/env bash

# path::remove "$(misc::this_script_dir)"
#shellcheck disable=SC2120
function misc::this_script_dir() {
  args::check_no_args "$@"
  cd -- "$(dirname -- "${BASH_SOURCE[1]}")" &> '/dev/null' && pwd
}

#shellcheck disable=SC2120
function misc::auto_answer() {
  args::check_no_args "$@"
  [[ "${SCRIPTS_AUTO_ANSWER:-}" == [Yy] ]]
}
