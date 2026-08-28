bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/namerefs.bash"
}

@test "assert_available: distinct names are accepted" {
  run --separate-stderr namerefs::assert_available 'candidates' '__shell_scripts_filter_ref'
  assert_success
  refute_output
  refute_stderr
}

@test "assert_available: the reserved name dies naming it" {
  run --separate-stderr namerefs::assert_available '__shell_scripts_filter_ref' '__shell_scripts_filter_ref'
  assert_failure 1
  assert_stderr --partial "out-parameter may not be named '__shell_scripts_filter_ref'"
}

@test "assert_available: comparison is exact, not a prefix or substring match" {
  run --separate-stderr namerefs::assert_available '__shell_scripts_filter_re' '__shell_scripts_filter_ref'
  assert_success
  run --separate-stderr namerefs::assert_available '__shell_scripts_filter_refx' '__shell_scripts_filter_ref'
  assert_success
  run --separate-stderr namerefs::assert_available 'x__shell_scripts_filter_ref' '__shell_scripts_filter_ref'
  assert_success
}

@test "assert_available: empty requested name is accepted against a real reserved name" {
  run --separate-stderr namerefs::assert_available '' '__shell_scripts_filter_ref'
  assert_success
}

@test "assert_available: two empty strings collide" {
  run --separate-stderr namerefs::assert_available '' ''
  assert_failure 1
  assert_stderr --partial 'out-parameter may not be named'
}

@test "assert_available: 0 args dies" {
  run --separate-stderr namerefs::assert_available
  assert_failure
  assert_stderr --partial 'Expected exactly 2 arguments'
}

@test "assert_available: 1 arg dies" {
  run --separate-stderr namerefs::assert_available 'only'
  assert_failure
  assert_stderr --partial 'Expected exactly 2 arguments'
}

@test "assert_available: 3 args dies" {
  run --separate-stderr namerefs::assert_available 'a' 'b' 'c'
  assert_failure
  assert_stderr --partial 'Expected exactly 2 arguments'
}
