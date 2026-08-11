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
  [[ "${first_line}" =~ ^#!.*[/\ ](((ba)?sh)|bats)([[:space:]]|$) ]]
}

# @description Return true if the given path is a shell file: either it carries a shell
# extension (.sh/.bash/.bats) or its first line is a shell shebang. Mirrors how
# `shfmt --find` classifies files when scanning a directory, so an explicitly
# passed file is judged by the same rule a discovered one is. .bats is matched by
# extension because those files open with `@test`, not a shebang.
# @arg $1 file path
# @exitcode 0 if true
# @exitcode 1 if false
function shell_scripts::is_shell_file() {
  args::check_exactly_1_arg "$@"
  local -r file="$1"
  case "${file}" in
    *.sh | *.bash | *.bats) return 0 ;;
  esac
  shell_scripts::has_shell_shebang "${file}"
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

# @description Emit shell-script paths under the repo root when called with no args; excludes
# /other/ (third-party copies), /.shdoc/ (vendored shdoc submodule),
# /.direnv/ (Nix/direnv-managed cache), and /test/bats/,
# /test/test_helper/bats-support/, /test/test_helper/bats-assert/
# (vendored BATS submodules). With args: each arg is either a directory
# (recursed via `shfmt --find`) or a file (emitted as-is). Caller must
# validate that each arg exists before calling.
# Output: stdout — shell script file paths, one per line
# @arg $@ files or directories to search (optional; defaults to all scripts under the repo root)
function shell_scripts::find() {
  if args::no_args "$@"; then
    # REPO_DIR override seam: production leaves it unset and the repo root is
    # derived via git; tests set REPO_DIR to point the scan at a fixture tree.
    local repo_dir
    repo_dir="${REPO_DIR:-$(git rev-parse --show-toplevel)}"
    shfmt --find "${repo_dir}" \
      | grep --invert-match --extended-regexp '/(\.shdoc|\.direnv|other|test/bats|test/test_helper/bats-(support|assert))/'
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
    if [[ "${file}" == */other/* ]]; then
      if ! prompt::ny "Process file under other/: ${file}?"; then
        continue
      fi
    fi
    _out_ref+=("${file}")
  done
}

# @description Emit shell-script paths that live directly in the repo root (no
# subdirectories). Used by .ci/build-docs and .ci/check-shdoc-headers to enumerate
# project-root executables such as shellcheck-scripts,
# check-scripts, run-install-scripts, run-set-up-scripts, run-tests.
# Filters to files whose first line contains a bash/sh/bats shebang
# (via shell_scripts::has_shell_shebang). Excludes the root-level
# .functions.bash loader, which is a sourced library file rather than a
# top-level executable.
# @stdout file paths, one per line
# @noargs
function shell_scripts::find_root_only() {
  args::check_no_args "$@"
  # REPO_DIR override seam: production leaves it unset and the repo root is
  # derived via git; tests set REPO_DIR to point the scan at a fixture tree.
  local repo_dir
  repo_dir="${REPO_DIR:-$(git rev-parse --show-toplevel)}"
  local file
  for file in "${repo_dir}"/*; do
    if ! files::exists "${file}"; then
      continue
    fi
    if [[ "$(basename -- "${file}")" == '.functions.bash' ]]; then
      continue
    fi
    if shell_scripts::has_shell_shebang "${file}"; then
      printf '%s\n' "${file}"
    fi
  done
}

# @description Return true if a top-level script is required to call
# args::handle_help_flag. CLAUDE.md mandates the call on every top-level script
# with two exemptions, and both are structural rather than listed: a pass-through
# script carries the mandatory `pass-through` comment, and a standalone script
# never sources the function library, so the helper does not exist for it to
# call. The library test matches `functions.bash` rather than any source line —
# a misc/ script sourcing ~/.profile is still standalone, while a Docker script
# sourcing ${DOCKER_COMPOSE_DIR}/functions.bash gets this repo's helpers
# transitively and is not exempt.
# @arg $1 file path to script
# @exitcode 0 the script must call args::handle_help_flag
# @exitcode 1 the script is exempt as a pass-through or a standalone
function shell_scripts::requires_help_flag() {
  args::check_exactly_1_arg "$@"
  local -r file="$1"
  if ! grep --quiet --extended-regexp '^[[:space:]]*source .*functions\.bash' "${file}"; then
    return 1
  fi
  ! grep --quiet --extended-regexp '#.*pass-through' "${file}"
}
