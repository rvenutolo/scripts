#!/usr/bin/env bash

# $1 = executable
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

# $1 = executable
# Prints the absolute path of the executable (first match on PATH), or empty
# if not found. Same PATH-stripping as commands::executable_exists so wrappers in
# main/ and other/ don't mask the real binary.
function commands::executable_path() {
  args::check_exactly_1_arg "$@"
  (
    path::remove "${SCRIPTS_DIR}/main"
    path::remove "${SCRIPTS_DIR}/other"
    type -Pf "$1" 2> '/dev/null'
  )
}

# $1 = function
function commands::function_exists() {
  args::check_exactly_1_arg "$@"
  declare -f "$1" > '/dev/null' 2>&1
}
