#!/usr/bin/env bash

# $1 = executable
function executable_exists() {
  check_exactly_1_arg "$@"
  (
    ## remove from path so scripts that mask commands are no longer on PATH, ex: mvn
    ## do this in a subshell to not mess up PATH in parent shell
    path_remove "${SCRIPTS_DIR}/main"
    path_remove "${SCRIPTS_DIR}/other"
    # executables / no builtins, aliases, or functions
    type -aPf "$1" > '/dev/null' 2>&1
  )
}

# $1 = function
function function_exists() {
  check_exactly_1_arg "$@"
  declare -f "$1" > '/dev/null' 2>&1
}
