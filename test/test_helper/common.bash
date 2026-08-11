#!/usr/bin/env bash

# Shared test setup loader for all *.bats files under test/functions/, test/ci/,
# and test/root/.
# Each .bats file's setup() loads this, then sources the file under test.
#
# Globals exported:
#   REPO_DIR     — repo root, resolved from BATS_TEST_DIRNAME
#   SCRIPTS_DIR  — = repo-root/scripts, the function library
#
# bats-support / bats-assert are loaded here so individual test files do not
# repeat the relative-path dance.

# BATS_TEST_DIRNAME points at test/functions (the dir of the running .bats file).
# Repo root is two levels up; the function library lives under scripts/.
REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
SCRIPTS_DIR="${REPO_DIR}/scripts"
export REPO_DIR SCRIPTS_DIR

# --- #248 hardening: every test is hermetic w.r.t. the real repo ---
# A caller (e.g. the pre-push hook after a worktree push) may carry repo-scoped GIT_* vars;
# with GIT_DIR set, `git -C <fixture>` ignores the fixture path and operates on the real
# repo. Unset them all. Inline rather than git::clear_local_env: the function library is
# the code under test and must not be a dependency of the harness.
_git_local_env_vars="$(git rev-parse --local-env-vars)"
while IFS= read -r _git_env_var; do
  unset "${_git_env_var}"
done <<< "${_git_local_env_vars}"
unset _git_local_env_vars _git_env_var

# Host git config must never leak into fixtures (a global commit.gpgsign=true used to; a
# fixture once wrote the inverse back into the real shared config — #248).
export GIT_CONFIG_GLOBAL='/dev/null'
export GIT_CONFIG_SYSTEM='/dev/null'

# Upward repo discovery from a fixture path must never cross into the real repo. (This does
# not protect discovery when CWD *is* the repo root — the cd below handles that class.)
export GIT_CEILING_DIRECTORIES="${REPO_DIR}"

# Fail the test loudly if the per-test tmpdir is unusable or inside the repo — a wrong
# fixture root is exactly how git commands end up aimed at the real checkout (#248).
# Inline [[ ]] checks: strings.bash/dirs.bash are code under test, not harness deps.
if [[ -z "${BATS_TEST_TMPDIR:-}" ]] || [[ ! -d "${BATS_TEST_TMPDIR}" ]]; then
  printf 'common.bash: BATS_TEST_TMPDIR missing or not a directory (#248)\n' >&2
  return 1
fi
_bats_tmp_real="$(cd "${BATS_TEST_TMPDIR}" && pwd -P)"
if [[ "${_bats_tmp_real}" == "${REPO_DIR}" || "${_bats_tmp_real}" == "${REPO_DIR}"/* ]]; then
  printf 'common.bash: BATS_TEST_TMPDIR resolves inside the repo: %s (#248)\n' "${_bats_tmp_real}" >&2
  return 1
fi
unset _bats_tmp_real

# No test body executes with CWD inside the real repo: an empty/botched path in a
# `git -C "${var}"` call resolves to CWD, which must never be the real checkout (#248).
cd "${BATS_TEST_TMPDIR}" || return 1

load "${REPO_DIR}/test/test_helper/bats-support/load"
load "${REPO_DIR}/test/test_helper/bats-assert/load"

# log.bash is sourced eagerly because args::check_* helpers call log::die on failure.
# shellcheck disable=SC1091 # path resolved at runtime via SCRIPTS_DIR
source "${SCRIPTS_DIR}/functions/log.bash"
