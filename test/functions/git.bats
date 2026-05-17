#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/git.bash"
}

# ---------- git::is_git_repo ----------

@test "is_git_repo: freshly inited repo -> true" {
  git -C "${BATS_TEST_TMPDIR}" init --quiet
  run git::is_git_repo "${BATS_TEST_TMPDIR}"
  assert_success
}

@test "is_git_repo: subdir of repo -> true" {
  git -C "${BATS_TEST_TMPDIR}" init --quiet
  mkdir --parents "${BATS_TEST_TMPDIR}/sub/nested"
  run git::is_git_repo "${BATS_TEST_TMPDIR}/sub/nested"
  assert_success
}

@test "is_git_repo: bare repo -> true" {
  local bare="${BATS_TEST_TMPDIR}/bare.git"
  git init --bare --quiet "${bare}"
  run git::is_git_repo "${bare}"
  assert_success
}

@test "is_git_repo: non-repo dir -> false" {
  mkdir --parents "${BATS_TEST_TMPDIR}/plain"
  run git::is_git_repo "${BATS_TEST_TMPDIR}/plain"
  assert_failure
}

@test "is_git_repo: nonexistent path -> false" {
  run git::is_git_repo "${BATS_TEST_TMPDIR}/nope"
  assert_failure
}

@test "is_git_repo: regular file -> false" {
  : > "${BATS_TEST_TMPDIR}/afile"
  run git::is_git_repo "${BATS_TEST_TMPDIR}/afile"
  assert_failure
}

@test "is_git_repo: dies with 0 args" {
  run git::is_git_repo
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "is_git_repo: dies with 2 args" {
  run git::is_git_repo 'a' 'b'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- git::assert_git_repo ----------

@test "assert_git_repo: repo -> silent success" {
  git -C "${BATS_TEST_TMPDIR}" init --quiet
  run git::assert_git_repo "${BATS_TEST_TMPDIR}"
  assert_success
  assert_output ''
}

@test "assert_git_repo: subdir of repo -> silent success" {
  git -C "${BATS_TEST_TMPDIR}" init --quiet
  mkdir --parents "${BATS_TEST_TMPDIR}/sub"
  run git::assert_git_repo "${BATS_TEST_TMPDIR}/sub"
  assert_success
  assert_output ''
}

@test "assert_git_repo: bare repo -> silent success" {
  local bare="${BATS_TEST_TMPDIR}/bare.git"
  git init --bare --quiet "${bare}"
  run git::assert_git_repo "${bare}"
  assert_success
  assert_output ''
}

@test "assert_git_repo: non-repo dir -> dies" {
  mkdir --parents "${BATS_TEST_TMPDIR}/plain"
  run git::assert_git_repo "${BATS_TEST_TMPDIR}/plain"
  assert_failure
  assert_output --partial 'is not a git repo'
}

@test "assert_git_repo: nonexistent path -> dies" {
  run git::assert_git_repo "${BATS_TEST_TMPDIR}/nope"
  assert_failure
  assert_output --partial 'is not a git repo'
}

@test "assert_git_repo: dies with 0 args" {
  run git::assert_git_repo
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "assert_git_repo: dies with 2 args" {
  run git::assert_git_repo 'a' 'b'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}
