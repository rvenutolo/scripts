#!/usr/bin/env bash

# Confined git operations for BATS fixture repos (#248). Every function dies unless its
# target path lives under BATS_TEST_TMPDIR, and run/run_bare pin the repository with
# explicit --git-dir/--work-tree so no inherited GIT_* context can retarget the call at
# the real repo. Requires args.bash and log.bash to be sourced (every .bats setup does).

# @description Die unless the given path is absolute and canonicalizes to
#              BATS_TEST_TMPDIR or a path below it. The path may not exist yet.
# @arg $1 dir fixture path to validate
function git_fixture::assert_confined() {
  args::check_exactly_1_arg "$@"
  local -r dir="$1"
  if [[ "${dir}" != /* ]]; then
    log::die "git_fixture: path is not absolute: '${dir}' (#248)"
  fi
  local tmp_real dir_real
  tmp_real="$(cd "${BATS_TEST_TMPDIR}" && pwd -P)"
  dir_real="$(realpath --canonicalize-missing -- "${dir}")"
  if [[ "${dir_real}" != "${tmp_real}" && "${dir_real}" != "${tmp_real}"/* ]]; then
    log::die "git_fixture: path escapes BATS_TEST_TMPDIR: '${dir}' -> '${dir_real}' (#248)"
  fi
}

# @description Create a work-tree git repo at dir (parents created), confined to the
#              per-test tmpdir.
# @arg $1 dir fixture repo path
# @arg $@ extra `git init` arguments (after the first arg), e.g. --initial-branch=main
function git_fixture::init() {
  args::check_at_least_1_arg "$@"
  local -r dir="$1"
  shift
  git_fixture::assert_confined "${dir}"
  mkdir --parents -- "${dir}"
  # Per-command env pin: a hostile inherited GIT_DIR wins over the positional dir in
  # `git init`, silently retargeting the init (#248) — override it for this call only.
  GIT_DIR="${dir}/.git" GIT_WORK_TREE="${dir}" git init --quiet "$@" "${dir}"
}

# @description Create a bare git repo at dir, confined to the per-test tmpdir.
# @arg $1 dir bare repo path
function git_fixture::init_bare() {
  args::check_exactly_1_arg "$@"
  local -r dir="$1"
  git_fixture::assert_confined "${dir}"
  # Per-command env pin — same #248 rationale as git_fixture::init.
  GIT_DIR="${dir}" git init --bare --quiet "${dir}"
}

# @description Run a git command against the work-tree fixture repo at dir, pinned via
#              explicit --git-dir/--work-tree (immune to inherited GIT_* context). -C keeps
#              relative pathspecs resolving inside the fixture.
# @arg $1 dir fixture repo path (must already exist)
# @arg $@ git command and arguments (after the first arg)
function git_fixture::run() {
  args::check_at_least_2_args "$@"
  local -r dir="$1"
  shift
  git_fixture::assert_confined "${dir}"
  git -C "${dir}" --git-dir="${dir}/.git" --work-tree="${dir}" "$@" # -C: no long-form equivalent
}

# @description Run a git command against the bare fixture repo at dir, pinned via
#              explicit --git-dir (immune to inherited GIT_* context).
# @arg $1 dir bare repo path (must already exist)
# @arg $@ git command and arguments (after the first arg)
function git_fixture::run_bare() {
  args::check_at_least_2_args "$@"
  local -r dir="$1"
  shift
  git_fixture::assert_confined "${dir}"
  git -C "${dir}" --git-dir="${dir}" "$@" # -C: no long-form equivalent
}
