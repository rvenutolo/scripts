#!/usr/bin/env bash

# @description Return true if the named executable is on PATH, excluding wrappers in main/ and other/.
# @arg $1 executable name
function commands::executable_exists() {
  args::check_exactly_1_arg "$@"
  (
    ## remove from path so scripts that mask commands are no longer on PATH, ex: mvn
    ## do this in a subshell to not mess up PATH in parent shell
    path::remove "${SCRIPTS_DIR}/main"
    path::remove "${SCRIPTS_DIR}/other"
    # executables / no builtins, aliases, or functions
    type -aPf "$1" > '/dev/null' 2>&1
  )
}

# @description Print the absolute path of an executable (first match on PATH), excluding wrappers in main/ and other/.
# Output: stdout — absolute path, or empty string if not found
# @arg $1 executable name
function commands::executable_path() {
  args::check_exactly_1_arg "$@"
  (
    path::remove "${SCRIPTS_DIR}/main"
    path::remove "${SCRIPTS_DIR}/other"
    type -Pf "$1" 2> '/dev/null'
  )
}

# @description Return true if the named shell function is defined in the current shell.
# @arg $1 function name
function commands::function_exists() {
  args::check_exactly_1_arg "$@"
  declare -f "$1" > '/dev/null' 2>&1
}
