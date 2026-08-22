#!/usr/bin/env bats

# Tests for test/test_helper/git_fixture.bash (helper lives in test_helper/, not
# scripts/functions/ — this dir is used because the runner only scans functions/ci/root).

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  load '../test_helper/git_fixture'
}

# ---------- harness env (Task 3 layer, asserted here) ----------

@test "harness: repo-scoped git env is stripped and config env pinned" {
  [[ -z "${GIT_DIR:-}" ]]
  [[ -z "${GIT_WORK_TREE:-}" ]]
  [[ "${GIT_CONFIG_GLOBAL}" == '/dev/null' ]]
  [[ "${GIT_CONFIG_SYSTEM}" == '/dev/null' ]]
  [[ "${GIT_CEILING_DIRECTORIES}" == "${REPO_DIR}" ]]
}

@test "harness: CWD is the per-test tmpdir, not the repo" {
  [[ "$(pwd -P)" == "$(cd "${BATS_TEST_TMPDIR}" && pwd -P)" ]]
}

# ---------- git_fixture::assert_confined ----------

@test "assert_confined: accepts tmpdir itself and a child path" {
  git_fixture::assert_confined "${BATS_TEST_TMPDIR}"
  git_fixture::assert_confined "${BATS_TEST_TMPDIR}/repo"
}

@test "assert_confined: dies on empty path" {
  run --separate-stderr git_fixture::assert_confined ''
  assert_failure
  assert_stderr --partial "git_fixture: path is not absolute: ''"
}

@test "assert_confined: dies on relative path" {
  run --separate-stderr git_fixture::assert_confined 'repo'
  assert_failure
  assert_stderr --partial "git_fixture: path is not absolute: 'repo'"
}

@test "assert_confined: dies on absolute path outside tmpdir" {
  run --separate-stderr git_fixture::assert_confined "${REPO_DIR}"
  assert_failure
  assert_stderr --partial 'git_fixture: path escapes BATS_TEST_TMPDIR'
}

@test "assert_confined: dies on dot-dot escape from tmpdir" {
  run --separate-stderr git_fixture::assert_confined "${BATS_TEST_TMPDIR}/../escape"
  assert_failure
  assert_stderr --partial 'git_fixture: path escapes BATS_TEST_TMPDIR'
}

@test "assert_confined: dies with 0 and 2 args" {
  run --separate-stderr git_fixture::assert_confined
  assert_failure
  assert_stderr --partial 'Expected exactly 1 argument'
  run --separate-stderr git_fixture::assert_confined "${BATS_TEST_TMPDIR}" 'extra'
  assert_failure
  assert_stderr --partial 'Expected exactly 1 argument'
}

# ---------- git_fixture::init / init_bare ----------

@test "init: creates a work-tree repo at the given path" {
  git_fixture::init "${BATS_TEST_TMPDIR}/repo"
  [[ -d "${BATS_TEST_TMPDIR}/repo/.git" ]]
}

@test "init: forwards extra init args" {
  git_fixture::init "${BATS_TEST_TMPDIR}/repo" --initial-branch=trunk
  run git_fixture::run "${BATS_TEST_TMPDIR}/repo" symbolic-ref --short HEAD
  assert_success
  assert_output 'trunk'
}

@test "init: dies on a path outside tmpdir" {
  run --separate-stderr git_fixture::init '/tmp/definitely-outside-248'
  assert_failure
  assert_stderr --partial 'git_fixture: path escapes BATS_TEST_TMPDIR'
  [[ ! -e '/tmp/definitely-outside-248' ]]
}

@test "init_bare: creates a bare repo" {
  git_fixture::init_bare "${BATS_TEST_TMPDIR}/bare"
  run git_fixture::run_bare "${BATS_TEST_TMPDIR}/bare" rev-parse --is-bare-repository
  assert_success
  assert_output 'true'
}

# ---------- git_fixture::run ----------

@test "run: config + commit land in the fixture" {
  git_fixture::init "${BATS_TEST_TMPDIR}/repo"
  git_fixture::run "${BATS_TEST_TMPDIR}/repo" config user.name 'Fixture'
  git_fixture::run "${BATS_TEST_TMPDIR}/repo" config user.email 'f@example.com'
  git_fixture::run "${BATS_TEST_TMPDIR}/repo" config commit.gpgSign false
  git_fixture::run "${BATS_TEST_TMPDIR}/repo" commit --quiet --allow-empty --message='c1'
  run git_fixture::run "${BATS_TEST_TMPDIR}/repo" log --format=%s
  assert_success
  assert_output 'c1'
}

@test "run: relative pathspecs resolve inside the fixture" {
  git_fixture::init "${BATS_TEST_TMPDIR}/repo"
  touch "${BATS_TEST_TMPDIR}/repo/tracked-file"
  git_fixture::run "${BATS_TEST_TMPDIR}/repo" add -- tracked-file
  run git_fixture::run "${BATS_TEST_TMPDIR}/repo" ls-files
  assert_success
  assert_output 'tracked-file'
}

@test "run: dies with fewer than 2 args" {
  run --separate-stderr git_fixture::run "${BATS_TEST_TMPDIR}"
  assert_failure
  assert_stderr --partial 'Expected at least 2 arguments'
}

# ---------- #248 regression: hostile inherited GIT_DIR cannot retarget fixtures ----------

@test "regression: hostile GIT_DIR does not leak fixture writes into a victim repo" {
  git_fixture::init "${BATS_TEST_TMPDIR}/victim"
  git_fixture::run "${BATS_TEST_TMPDIR}/victim" config user.name 'Victim'
  git_fixture::run "${BATS_TEST_TMPDIR}/victim" config user.email 'v@example.com'
  git_fixture::run "${BATS_TEST_TMPDIR}/victim" config commit.gpgSign false
  git_fixture::run "${BATS_TEST_TMPDIR}/victim" commit --quiet --allow-empty --message='real'
  local victim_head
  victim_head="$(git_fixture::run "${BATS_TEST_TMPDIR}/victim" rev-parse HEAD)"

  # Simulate the #248 hook environment: absolute GIT_DIR/GIT_INDEX_FILE/GIT_OBJECT_DIRECTORY
  # all aimed at the victim. GIT_DIR alone is neutralized by the --git-dir pin, but
  # GIT_INDEX_FILE and GIT_OBJECT_DIRECTORY are repo-scoped vars the pin does not touch.
  export GIT_DIR="${BATS_TEST_TMPDIR}/victim/.git"
  export GIT_INDEX_FILE="${BATS_TEST_TMPDIR}/victim/.git/index"
  export GIT_OBJECT_DIRECTORY="${BATS_TEST_TMPDIR}/victim/.git/objects"
  git_fixture::init "${BATS_TEST_TMPDIR}/fixture"
  git_fixture::run "${BATS_TEST_TMPDIR}/fixture" config user.name 'BATS Fixture'
  git_fixture::run "${BATS_TEST_TMPDIR}/fixture" config user.email 'bats@example.com'
  git_fixture::run "${BATS_TEST_TMPDIR}/fixture" config commit.gpgSign false
  git_fixture::run "${BATS_TEST_TMPDIR}/fixture" commit --quiet --allow-empty --message='stray'
  unset GIT_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY

  # Victim untouched: same HEAD, original identity, and clean working state (a hostile
  # GIT_INDEX_FILE redirect would have staged the fixture's writes into the victim's index).
  run git_fixture::run "${BATS_TEST_TMPDIR}/victim" rev-parse HEAD
  assert_output "${victim_head}"
  run git_fixture::run "${BATS_TEST_TMPDIR}/victim" config user.name
  assert_output 'Victim'
  run git_fixture::run "${BATS_TEST_TMPDIR}/victim" status --porcelain
  assert_success
  assert_output ''
  # Fixture received the writes.
  run git_fixture::run "${BATS_TEST_TMPDIR}/fixture" log --format=%s
  assert_output 'stray'
}
