setup() {
  load '../test_helper/common'
  AGG="${REPO_DIR}/.ci/run-governance-checks"
}

# .ci/run-governance-checks (an aggregator) derives its own repo root via
# `git rev-parse --show-toplevel`, as do the sub-checks it shells out to.
# common.bash's #248 hardening leaves CWD at BATS_TEST_TMPDIR (outside any git
# repo) by design, so cd into REPO_DIR before every invocation — this test
# targets the real repo.
run_check() {
  cd "${REPO_DIR}" || return 1
  run "$@"
}

@test "runs clean against the real repo" {
  run_check "${AGG}"
  assert_success
}

@test "dies when given an argument" {
  run_check "${AGG}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}
