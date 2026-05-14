#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/time.bash"
}

# ---------- time::calc_elapsed ----------

@test "calc_elapsed: equal times -> 0s" {
  run time::calc_elapsed 100 100
  assert_success
  assert_output '0s'
}

@test "calc_elapsed: 1 second" {
  run time::calc_elapsed 100 101
  assert_success
  assert_output '1s'
}

@test "calc_elapsed: 59 seconds" {
  run time::calc_elapsed 0 59
  assert_success
  assert_output '59s'
}

@test "calc_elapsed: exactly 1 minute" {
  run time::calc_elapsed 0 60
  assert_success
  assert_output '1m 0s'
}

@test "calc_elapsed: 1 minute 1 second" {
  run time::calc_elapsed 0 61
  assert_success
  assert_output '1m 1s'
}

@test "calc_elapsed: 59 minutes 59 seconds" {
  run time::calc_elapsed 0 3599
  assert_success
  assert_output '59m 59s'
}

@test "calc_elapsed: exactly 1 hour" {
  run time::calc_elapsed 0 3600
  assert_success
  assert_output '1h 0s'
}

@test "calc_elapsed: 1 hour 1 second" {
  run time::calc_elapsed 0 3601
  assert_success
  assert_output '1h 1s'
}

@test "calc_elapsed: 1 hour 1 minute 1 second" {
  run time::calc_elapsed 0 3661
  assert_success
  assert_output '1h 1m 1s'
}

@test "calc_elapsed: 2 hours 3 minutes 4 seconds" {
  run time::calc_elapsed 0 7384
  assert_success
  assert_output '2h 3m 4s'
}

@test "calc_elapsed: dies with 1 arg" {
  run time::calc_elapsed 100
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "calc_elapsed: dies with 3 args" {
  run time::calc_elapsed 0 1 2
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "calc_elapsed: handles leading-zero input '08' '09'" {
  run time::calc_elapsed 08 09
  assert_success
  assert_output '1s'
}

@test "calc_elapsed: end < start -> dies" {
  run time::calc_elapsed 100 50
  assert_failure
}

# ---------- time::shell_elapsed_time ----------

# Note: time::shell_elapsed_time is a 3-line wrapper:
#   args::check_no_args "$@"
#   time::calc_elapsed 0 "${SECONDS}"
#
# Asserting that `SECONDS=3661 → "1h 1m 1s"` requires the bash interpreter to
# expand "${SECONDS}" within the same wall-second as the assignment, which is
# flaky under parallel suite load (SECONDS may tick to 3662 before the read).
# Instead, mock time::calc_elapsed and assert the wrapper delegates correctly:
# first arg is `0`, second arg is a non-negative integer (SECONDS at call time).
# The value-formatting logic is exhaustively covered by the calc_elapsed tests
# above; this test only verifies the wiring.

@test "shell_elapsed_time: delegates to calc_elapsed with 0 and SECONDS" {
  # Override calc_elapsed for this test only; bats isolates each @test in its own subshell.
  function time::calc_elapsed() {
    printf 'start=%s end=%s\n' "$1" "$2"
  }
  SECONDS=42
  local actual
  actual="$(time::shell_elapsed_time)"
  [[ "${actual}" =~ ^start=0\ end=([0-9]+)$ ]]
  local seconds_seen="${BASH_REMATCH[1]}"
  # SECONDS may have ticked between assignment and read; accept anything >= 42.
  (( seconds_seen >= 42 ))
}

@test "shell_elapsed_time: dies when called with arg" {
  run time::shell_elapsed_time 'unexpected'
  assert_failure
  assert_output --partial 'Expected no arguments'
}
