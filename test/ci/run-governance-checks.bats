setup() {
  load '../test_helper/common'
  AGG="${REPO_DIR}/.ci/run-governance-checks"
}

@test "runs clean against the real repo" {
  run "${AGG}"
  assert_success
}

@test "dies when given an argument" {
  run "${AGG}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}
