setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/build-docs"
  # Redirect generated docs to a per-test tmpdir so the suite never mutates the
  # real .docs/ and parallel runs of this file don't race on shared output.
  export DOCS_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/docs"
}

@test "clean run exits 0" {
  run "${CHECK}"
  assert_success
}

@test "--help exits 0 and prints help text" {
  run "${CHECK}" --help
  assert_success
  assert_output --partial 'build-docs'
}

@test "dies when given an argument" {
  run "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "populates the functions docs dir with at least one markdown page" {
  run "${CHECK}"
  assert_success
  run find "${DOCS_DIR_OVERRIDE}/functions" -maxdepth 1 -type f -name '*.md'
  assert_success
  assert_output --partial '.md'
}

@test "populates the scripts docs dir with at least one markdown page" {
  run "${CHECK}"
  assert_success
  run find "${DOCS_DIR_OVERRIDE}/scripts" -type f -name '*.md'
  assert_success
  assert_output --partial '.md'
}
