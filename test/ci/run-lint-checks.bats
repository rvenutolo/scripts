setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  AGG="${REPO_DIR}/.ci/run-lint-checks"
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

@test "fails (exit 1) when a sub-lint fails but still runs the rest" {
  # Stub actionlint (first lint) to fail; aggregator must aggregate, not abort.
  path_shim::add actionlint 'echo "stub actionlint fail" >&2; exit 1'
  run "${AGG}"
  assert_failure
  assert_output --partial 'one or more lint checks failed'
}
