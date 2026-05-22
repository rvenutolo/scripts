#!/usr/bin/env bash

# @description Return true if the given file's first line contains a bash, sh, or bats
# shebang. bats is included because shfmt and shellcheck both auto-detect it
# from the shebang and apply their bats-aware dialect.
# @arg $1 file path
# @exitcode 0 if true
# @exitcode 1 if false
function shell_scripts::has_shell_shebang() {
  args::check_exactly_1_arg "$@"
  local -r file="$1"
  local first_line
  first_line="$(head --lines=1 -- "${file}")"
  [[ ${first_line} =~ ^#!.*[/\ ](((ba)?sh)|bats)([[:space:]]|$) ]]
}

# @description Die if any of the given paths does not exist on disk.
# @arg $@ paths to validate
function shell_scripts::assert_paths_exist() {
  # pass-through: any arg count valid (variadic; no-ops on empty input)
  local arg
  for arg in "$@"; do
    if ! files::any_exists "${arg}"; then
      log::die "${arg} does not exist"
    fi
  done
}

# @description Emit shell-script paths under SCRIPTS_DIR when called with no args; excludes
# /other/ (third-party copies), /.shdoc/ (vendored shdoc submodule), and
# /test/bats/, /test/test_helper/bats-support/, /test/test_helper/bats-assert/
# (vendored BATS submodules). With args: each arg is either a directory
# (recursed via `shfmt --find`) or a file (emitted as-is). Caller must
# validate that each arg exists before calling.
# Output: stdout — shell script file paths, one per line
# @arg $@ files or directories to search (optional; defaults to all scripts under SCRIPTS_DIR)
function shell_scripts::find() {
  if args::no_args "$@"; then
    shfmt --find "${SCRIPTS_DIR}" |
      grep --invert-match --extended-regexp '/(\.shdoc|other|test/bats|test/test_helper/bats-(support|assert))/'
    return
  fi
  local arg
  for arg in "$@"; do
    if dirs::exists "${arg}"; then
      shfmt --find "${arg}"
    else
      printf '%s\n' "${arg}"
    fi
  done
}

# @description Filter candidate paths down to processable shell scripts:
# - Files without a bash/sh shebang are warned and skipped.
# - Files under /other/ require interactive confirmation (prompt::ny).
# Output goes into a caller-provided array via nameref so prompts can run
# in the caller's shell (avoids capturing prompt output in process subs).
#
# $2..$N = candidate paths
# @arg $1 name of output array (will be cleared and populated)
function shell_scripts::filter() {
  args::check_at_least_1_arg "$@"
  system::require_bash_version 4 3
  local -r out_name="$1"
  local -n _out_ref="${out_name}"
  shift
  _out_ref=()
  local file
  for file in "$@"; do
    if ! shell_scripts::has_shell_shebang "${file}"; then
      log::log "Skipping (no bash/sh shebang): ${file}"
      continue
    fi
    if [[ ${file} == */other/* ]]; then
      if ! prompt::ny "Process file under other/: ${file}?"; then
        continue
      fi
    fi
    _out_ref+=("${file}")
  done
}

# @description Emit shell-script paths that live directly in SCRIPTS_DIR (no
# subdirectories). Used by .ci/build-docs and .ci/check-shdoc-headers to enumerate
# project-root executables such as shellcheck-scripts,
# check-scripts, run-install-scripts, run-set-up-scripts, run-tests.
# Filters to files whose first line contains a bash/sh/bats shebang
# (via shell_scripts::has_shell_shebang). Excludes the root-level
# functions.bash loader, which is a sourced library file rather than a
# top-level executable.
# @stdout file paths, one per line
# @noargs
function shell_scripts::find_root_only() {
  args::check_no_args "$@"
  local file
  for file in "${SCRIPTS_DIR}"/*; do
    if ! files::exists "${file}"; then
      continue
    fi
    if [[ "$(basename -- "${file}")" == 'functions.bash' ]]; then
      continue
    fi
    if shell_scripts::has_shell_shebang "${file}"; then
      printf '%s\n' "${file}"
    fi
  done
}
