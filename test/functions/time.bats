#!/usr/bin/env bats

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

@test "shell_elapsed_time: SECONDS=0 -> 0s" {
  SECONDS=0
  run time::shell_elapsed_time
  assert_success
  assert_output '0s'
}

@test "shell_elapsed_time: SECONDS=1 -> 1s" {
  SECONDS=1
  run time::shell_elapsed_time
  assert_success
  assert_output '1s'
}

@test "shell_elapsed_time: SECONDS=3661 -> 1h 1m 1s" {
  SECONDS=3661
  run time::shell_elapsed_time
  assert_success
  assert_output '1h 1m 1s'
}

@test "shell_elapsed_time: dies when called with arg" {
  run time::shell_elapsed_time 'unexpected'
  assert_failure
  assert_output --partial 'Expected no arguments'
}
