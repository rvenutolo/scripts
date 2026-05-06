#!/usr/bin/env bash

# $1 = file
function has_shell_shebang() {
  check_exactly_1_arg "$@"
  local first_line
  first_line="$(head --lines=1 -- "$1")"
  [[ "${first_line}" =~ ^#!.*[/\ ](ba)?sh([[:space:]]|$) ]]
}

# Die if any positional arg does not exist on disk.
function assert_paths_exist() {
  local arg
  for arg in "$@"; do
    if [[ ! -e "${arg}" ]]; then
      die "${arg} does not exist"
    fi
  done
}

# Emit shell-script paths under SCRIPTS_DIR (excluding /other/) when called
# with no args. With args: each arg is either a directory (recursed via
# `shfmt --find`) or a file (emitted as-is). Caller must validate that
# each arg exists before calling.
function find_shell_scripts() {
  if [[ "$#" -eq 0 ]]; then
    shfmt --find "${SCRIPTS_DIR}" | grep --invert-match '/other/'
    return
  fi
  local arg
  for arg in "$@"; do
    if [[ -d "${arg}" ]]; then
      shfmt --find "${arg}"
    else
      printf '%s\n' "${arg}"
    fi
  done
}

# Filter candidate paths down to processable shell scripts:
# - Files without a bash/sh shebang are warned and skipped.
# - Files under /other/ require interactive confirmation (prompt_ny).
# Output goes into a caller-provided array via nameref so prompts can run
# in the caller's shell (avoids capturing prompt output in process subs).
#
# $1 = name of output array (will be cleared and populated)
# $2..$N = candidate paths
function filter_shell_scripts() {
  check_at_least_1_arg "$@"
  require_bash_version 4 3
  local -n _out_ref="$1"
  shift
  _out_ref=()
  local file
  for file in "$@"; do
    if ! has_shell_shebang "${file}"; then
      log "Skipping (no bash/sh shebang): ${file}"
      continue
    fi
    if [[ "${file}" == */other/* ]]; then
      if ! prompt_ny "Process file under other/: ${file}?"; then
        continue
      fi
    fi
    _out_ref+=("${file}")
  done
}
