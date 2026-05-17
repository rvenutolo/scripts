#!/usr/bin/env bash

# @description Return true if the given path is inside a git repository (work tree, bare repo, or .git dir).
# @arg $1 dir path
function git::is_git_repo() {
  args::check_exactly_1_arg "$@"
  local -r dir="$1"
  git -C "${dir}" rev-parse --git-dir > '/dev/null' 2>&1
}

# @description Die if the given path is not inside a git repository.
# @arg $1 dir path
# @exitcode 0 if true
# @exitcode 1 if false
function git::assert_git_repo() {
  args::check_exactly_1_arg "$@"
  local -r dir="$1"
  if ! git::is_git_repo "${dir}"; then
    log::die "${dir} is not a git repo"
  fi
}
