#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031 # BATS isolates each @test in its own subshell; export modifications are intentional and correctly scoped per-test

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/misc.bash"
}

@test "auto_answer: unset -> false" {
  unset SCRIPTS_AUTO_ANSWER || true
  run misc::auto_answer
  assert_failure
}

@test "auto_answer: empty -> false" {
  export SCRIPTS_AUTO_ANSWER=''
  run misc::auto_answer
  assert_failure
}

@test "auto_answer: 'y' -> true" {
  export SCRIPTS_AUTO_ANSWER='y'
  run misc::auto_answer
  assert_success
}

@test "auto_answer: 'Y' -> true" {
  export SCRIPTS_AUTO_ANSWER='Y'
  run misc::auto_answer
  assert_success
}

@test "auto_answer: 'n' -> false" {
  export SCRIPTS_AUTO_ANSWER='n'
  run misc::auto_answer
  assert_failure
}

@test "auto_answer: 'N' -> false" {
  export SCRIPTS_AUTO_ANSWER='N'
  run misc::auto_answer
  assert_failure
}

@test "auto_answer: 'yes' -> false (only single-char y/Y matches)" {
  export SCRIPTS_AUTO_ANSWER='yes'
  run misc::auto_answer
  assert_failure
}

@test "auto_answer: 'true' -> false" {
  export SCRIPTS_AUTO_ANSWER='true'
  run misc::auto_answer
  assert_failure
}

@test "auto_answer: '1' -> false" {
  export SCRIPTS_AUTO_ANSWER='1'
  run misc::auto_answer
  assert_failure
}

@test "auto_answer: dies with args" {
  export SCRIPTS_AUTO_ANSWER='y'
  run misc::auto_answer 'extra'
  assert_failure
  assert_output --partial 'Expected no arguments'
}
