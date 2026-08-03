#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031 # BATS runs each @test in a subshell; subshell-local mutations are intentional

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/strings.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/env.bash"
}

@test "assert_var_set: var set and non-empty -> success" {
  export FOO='value'
  run env::assert_var_set 'FOO'
  assert_success
  assert_output ''
}

@test "assert_var_set: var unset -> dies" {
  unset FOO || true
  run env::assert_var_set 'FOO'
  assert_failure
  assert_output --partial 'FOO not set'
}

@test "assert_var_set: var set to empty string -> dies" {
  export FOO=''
  run env::assert_var_set 'FOO'
  assert_failure
  assert_output --partial 'FOO not set'
}

@test "assert_var_set: multiple vars all set -> success" {
  export FOO='a' BAR='b' BAZ='c'
  run env::assert_var_set 'FOO' 'BAR' 'BAZ'
  assert_success
}

@test "assert_var_set: multiple vars one unset -> dies on the unset one" {
  export FOO='a' BAZ='c'
  unset BAR || true
  run env::assert_var_set 'FOO' 'BAR' 'BAZ'
  assert_failure
  assert_output --partial 'BAR not set'
}

@test "assert_var_set: multiple vars one empty -> dies on the empty one" {
  export FOO='a' BAR='' BAZ='c'
  run env::assert_var_set 'FOO' 'BAR' 'BAZ'
  assert_failure
  assert_output --partial 'BAR not set'
}

@test "assert_var_set: var set to whitespace-only -> success (non-empty per impl)" {
  export FOO='   '
  run env::assert_var_set 'FOO'
  assert_success
}

@test "assert_var_set: dies with 0 args" {
  run env::assert_var_set
  assert_failure
  assert_output --partial 'Expected at least 1 argument'
}
