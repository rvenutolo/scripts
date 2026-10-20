setup() {
  load '../test_helper/common'
  SCRIPT="${REPO_DIR}/.ci/check-tap-complete"
  TAP="${BATS_TEST_TMPDIR}/run.tap"
}

# Write the lines given as arguments to the TAP fixture, one per line.
write_tap() {
  printf '%s\n' "$@" > "${TAP}"
}

@test "a stream reporting every planned test passes" {
  write_tap '1..3' 'ok 1 first' 'ok 2 second' 'ok 3 third'
  run "${SCRIPT}" "${TAP}"
  assert_success
}

@test "failed and skipped results count as reported" {
  write_tap '1..3' 'ok 1 first' 'not ok 2 second' 'ok 3 third # skip not here'
  run "${SCRIPT}" "${TAP}"
  assert_success
}

@test "a stream cut off before its last test fails and names the counts" {
  write_tap '1..5' 'ok 1 first' 'ok 2 second' 'ok 3 third'
  run "${SCRIPT}" "${TAP}"
  assert_failure 1
  assert_output --partial '3 of 5'
}

@test "a stream with no results after its plan fails" {
  write_tap '1..2'
  run "${SCRIPT}" "${TAP}"
  assert_failure 1
  assert_output --partial '0 of 2'
}

@test "an empty plan with no results passes" {
  write_tap '1..0'
  run "${SCRIPT}" "${TAP}"
  assert_success
}

@test "a stream with no plan fails" {
  write_tap 'ok 1 first'
  run "${SCRIPT}" "${TAP}"
  assert_failure 1
  assert_output --partial 'no TAP plan'
}

@test "an empty file fails" {
  : > "${TAP}"
  run "${SCRIPT}" "${TAP}"
  assert_failure 1
  assert_output --partial 'no TAP plan'
}

@test "a stream with two plans fails" {
  write_tap '1..1' 'ok 1 first' '1..1' 'ok 1 first'
  run "${SCRIPT}" "${TAP}"
  assert_failure 1
  assert_output --partial 'more than one TAP plan'
}

@test "a duplicated result number does not stand in for a missing one" {
  write_tap '1..3' 'ok 1 first' 'ok 2 second' 'ok 2 second'
  run "${SCRIPT}" "${TAP}"
  assert_failure 1
  assert_output --partial 'test 3'
}

@test "a result numbered beyond the plan fails" {
  write_tap '1..2' 'ok 1 first' 'ok 2 second' 'ok 3 third'
  run "${SCRIPT}" "${TAP}"
  assert_failure 1
  assert_output --partial 'test 3'
}

@test "interleaved non-result lines are ignored" {
  write_tap 'kcov: warning: something' '1..2' 'ok 1 first' '# diagnostic' \
    'okay this is prose' '  ok 9 indented output' 'ok 2 second'
  run "${SCRIPT}" "${TAP}"
  assert_success
}

@test "a missing file dies" {
  run "${SCRIPT}" "${BATS_TEST_TMPDIR}/absent.tap"
  assert_failure 1
}

@test "dies when given no arguments" {
  run "${SCRIPT}"
  assert_failure 1
  assert_output --partial 'Expected exactly 1 argument'
}

@test "dies when given two arguments" {
  write_tap '1..0'
  run "${SCRIPT}" "${TAP}" "${TAP}"
  assert_failure 1
  assert_output --partial 'Expected exactly 1 argument'
}

@test "--help prints the description" {
  run "${SCRIPT}" --help
  assert_success
  assert_output --partial 'TAP'
}
