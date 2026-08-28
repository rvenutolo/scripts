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
# /other/ (third-party copies), /.shdoc/ (vendored shdoc submodule), and
# /.direnv/ (Nix/direnv-managed cache). With args: each arg is either a
# directory (recursed via `shfmt --find`) or a file (emitted as-is). Caller
# must validate that each arg exists before calling.
# Output: stdout — shell script file paths, one per line
# @arg $@ files or directories to search (optional; defaults to all scripts under the repo root)
# An empty result from the no-args form is treated as a misdirected scan rather
# than a clean one: it exits 1 instead of succeeding silently, so a caller cannot
# mistake a tree it never examined for a tree with nothing wrong in it.
# shell_scripts::find_root_only matches.
# @exitcode 0 at least one shell file was emitted
# @exitcode 1 the no-args scan matched nothing
function shell_scripts::find() {
  if args::no_args "$@"; then
    # REPO_DIR override seam: production leaves it unset and the repo root is
    # derived via git; tests set REPO_DIR to point the scan at a fixture tree.
    local repo_dir
    repo_dir="${REPO_DIR:-$(git rev-parse --show-toplevel)}"
    shfmt --find "${repo_dir}" \
      | grep --invert-match --extended-regexp '/(\.shdoc|\.direnv|other)/'
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
# - Files that are not shell files are warned and skipped. A shell file is one
#   carrying a .sh/.bash/.bats extension or a shell shebang (shell_scripts::is_shell_file),
#   the same predicate the shfmt step in check-scripts uses. Gating on the shebang
#   alone would leave 31 of 83 test files silently unlinted.
# - Files under /other/ require interactive confirmation (prompt::ny).
# Output goes into a caller-provided array via nameref so prompts can run
# in the caller's shell (avoids capturing prompt output in process subs).
#
# $2..$N = candidate paths
# @arg $1 name of output array (will be cleared and populated)
function shell_scripts::filter() {
  args::check_at_least_1_arg "$@"
  local -r out_name="$1"
  namerefs::assert_available "${out_name}" '__shell_scripts_filter_ref'
  local -n __shell_scripts_filter_ref="${out_name}"
  shift
  __shell_scripts_filter_ref=()
  local file
  for file in "$@"; do
    if ! shell_scripts::is_shell_file "${file}"; then
      log::log "Skipping (not a shell file): ${file}"
      continue
    fi
    if [[ "${file}" == */other/* ]]; then
      if ! prompt::ny "Process file under other/: ${file}?"; then
        continue
      fi
    fi
    __shell_scripts_filter_ref+=("${file}")
  done
}

# @description Emit shell-script paths that live directly in the repo root (no
# subdirectories). Used by .ci/build-docs and .ci/check-shdoc-headers to enumerate
# project-root executables such as shellcheck-scripts,
# check-scripts, run-install-scripts, run-set-up-scripts, run-tests.
# Filters to files whose first line contains a bash/sh/bats shebang
# (via shell_scripts::has_shell_shebang). Dotfiles are excluded wholesale — the
# `*` glob does not match them — so .envrc and a root-level .functions.bash
# loader never become candidates in the first place.
# @stdout file paths, one per line
# @noargs
# An empty result is treated as a misdirected scan, matching shell_scripts::find:
# it exits 1 rather than succeeding silently. No caller suppresses this — a repo
# root with no shell scripts is not a shape this project has.
# @exitcode 0 at least one root-level shell script was emitted
# @exitcode 1 the repo root holds no shell scripts
function shell_scripts::find_root_only() {
  args::check_no_args "$@"
  # REPO_DIR override seam: production leaves it unset and the repo root is
  # derived via git; tests set REPO_DIR to point the scan at a fixture tree.
  local repo_dir
  repo_dir="${REPO_DIR:-$(git rev-parse --show-toplevel)}"
  local file
  local -i found=0
  for file in "${repo_dir}"/*; do
    if ! files::exists "${file}"; then
      continue
    fi
    if shell_scripts::has_shell_shebang "${file}"; then
      printf '%s\n' "${file}"
      found+=1
    fi
  done
  ((found > 0))
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
#
# Deliberate looseness: `pass-through` marks two different CLAUDE.md exemptions —
# the help-flag one this predicate wants, and the arg-count-guard one, which a
# merely variadic script also carries. Three scripts (mvn-fresh, claude-resume,
# sync-flatpaks) carry the arity marker while still owning their own --help, so
# this reads them as exempt when they are not. That costs nothing today because
# all three call the helper anyway, and erring toward exempt keeps the predicate
# free of false positives. Tightening it needs a marker that distinguishes the
# two exemptions, which is a convention change rather than a lint change.
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
