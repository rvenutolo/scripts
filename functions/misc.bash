#!/usr/bin/env bash

# Print the directory containing the calling script (resolved at call time via BASH_SOURCE).
# Useful for computing paths relative to the script's own location, e.g.:
#   path::remove "$(misc::this_script_dir)"
# Output: stdout — absolute path of the calling script's directory
#shellcheck disable=SC2120
function misc::this_script_dir() {
  args::check_no_args "$@"
  cd -- "$(dirname -- "${BASH_SOURCE[1]}")" &> '/dev/null' && pwd
}

# Return true if the SCRIPTS_AUTO_ANSWER env var is set to 'y' or 'Y'.
# Used to non-interactively accept all prompts in automated runs.
#shellcheck disable=SC2120
function misc::auto_answer() {
  args::check_no_args "$@"
  [[ "${SCRIPTS_AUTO_ANSWER:-}" == [Yy] ]]
}
