#!/usr/bin/env bash

# @description Print the directory containing the calling script (resolved at call time via BASH_SOURCE).
# Useful for computing paths relative to the script's own location, e.g.:
#   path::remove "$(misc::this_script_dir)"
# Output: stdout — absolute path of the calling script's directory
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function misc::this_script_dir() {
  args::check_no_args "$@"
  cd -- "$(dirname -- "${BASH_SOURCE[1]}")" &> '/dev/null' && pwd
}

# @description Return true if the SCRIPTS_AUTO_ANSWER env var is set to 'y' or 'Y'.
# Used to non-interactively accept all prompts in automated runs.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function misc::auto_answer() {
  args::check_no_args "$@"
  [[ "${SCRIPTS_AUTO_ANSWER:-}" == [Yy] ]]
}

# @description Launch a GUI app detached from the terminal. Replaces the calling shell
# via exec; the launched process runs in a new session (via setsid --fork) with stdout
# and stderr discarded. Must be the last statement in the calling script — exec does
# not return. Use this instead of `cmd "$@" > '/dev/null' 2>&1 &` + `disown` (backgrounded
# commands are banned because their exit status does not propagate to the parent).
# @arg $1 GUI executable name or path
# @arg $@ remaining args passed verbatim to the GUI executable
function misc::exec_gui() {
  args::check_at_least_1_arg "$@"
  exec setsid --fork "$@" > '/dev/null' 2>&1
}
