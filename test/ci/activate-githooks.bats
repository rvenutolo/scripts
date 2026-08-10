setup() {
  load '../test_helper/common'
  SCRIPT="${REPO_DIR}/.ci/activate-githooks"
  # Resolve the tmpdir itself with pwd -P: BATS_TEST_TMPDIR can sit under a
  # symlinked TMPDIR, and both `git rev-parse --show-toplevel` and
  # GIT_CEILING_DIRECTORIES compare against symlink-free paths.
  TMP_ROOT="$(cd "${BATS_TEST_TMPDIR}" && pwd -P)"
  REPO="${TMP_ROOT}/repo"
  mkdir --parents "${REPO}"
  git init --quiet "${REPO}"
}

# Read back the repo-local core.hooksPath. Empty when unset.
hooks_path() {
  git -C "${REPO}" config --local --get core.hooksPath || true
}

# Run the script with the working directory set to the fixture repo (or to the
# given subdirectory of it), which is the only seam the script has.
run_activate() {
  cd "${REPO}" || return 1
  run "${SCRIPT}" "$@"
}

@test "sets core.hooksPath to .githooks when unset" {
  run_activate
  assert_equal "$(hooks_path)" '.githooks'
}

@test "exits 0 on first activation" {
  run_activate
  assert_success
}

@test "logs on first activation" {
  run_activate
  assert_success
  assert_output
  assert_output --partial '.githooks'
}

@test "a second run exits 0 and leaves the value alone" {
  run_activate
  assert_success
  run_activate
  assert_success
  assert_equal "$(hooks_path)" '.githooks'
}

@test "a second run produces no output" {
  run_activate
  assert_success
  run_activate
  refute_output
}

@test "overwrites a foreign core.hooksPath" {
  git -C "${REPO}" config --local core.hooksPath '.other-hooks'
  run_activate
  assert_success
  assert_equal "$(hooks_path)" '.githooks'
}

@test "names the old value when repointing a foreign core.hooksPath" {
  git -C "${REPO}" config --local core.hooksPath '.other-hooks'
  run_activate
  assert_success
  assert_output --partial '.other-hooks'
  assert_output --partial '.githooks'
}

@test "works when invoked from a subdirectory of the repo" {
  mkdir --parents "${REPO}/nested/deeper"
  cd "${REPO}/nested/deeper"
  run "${SCRIPT}"
  assert_success
  assert_equal "$(hooks_path)" '.githooks'
}

@test "dies when the working directory is not inside a git repo" {
  local -r not_a_repo="${TMP_ROOT}/not-a-repo"
  mkdir --parents "${not_a_repo}"
  # GIT_CEILING_DIRECTORIES stops git's upward .git search at the tmpdir, so this
  # test cannot go vacuous on a machine where TMPDIR happens to live inside a
  # repo. The precondition below proves the directory really does read as
  # non-repo before the script is exercised against it.
  export GIT_CEILING_DIRECTORIES="${TMP_ROOT}"
  run git -C "${not_a_repo}" rev-parse --show-toplevel
  assert_failure
  cd "${not_a_repo}"
  run "${SCRIPT}"
  assert_failure
  assert_output --partial 'not a git repo'
}

@test "dies when given an argument" {
  run_activate oops
  assert_failure
  assert_output --partial 'expected no arguments'
}

@test "activates hooks when SCRIPTS_DIR is unset" {
  cd "${REPO}"
  run env --unset=SCRIPTS_DIR "${SCRIPT}"
  assert_success
  assert_equal "$(hooks_path)" '.githooks'
}

@test "activates hooks under a minimal environment" {
  cd "${REPO}"
  run env --ignore-environment \
    "PATH=${PATH}" "HOME=${HOME}" "${SCRIPT}"
  assert_success
  assert_equal "$(hooks_path)" '.githooks'
}
