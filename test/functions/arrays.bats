#!/usr/bin/env bats

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/arrays.bash"
}

@test "to_lines: zero args -> empty output" {
  run arrays::to_lines
  assert_success
  assert_output ''
}

@test "to_lines: single arg -> one line" {
  run arrays::to_lines 'foo'
  assert_success
  assert_output 'foo'
}

@test "to_lines: two args -> two lines" {
  run arrays::to_lines 'foo' 'bar'
  assert_success
  assert_output $'foo\nbar'
}

@test "to_lines: three args preserve order" {
  run arrays::to_lines 'a' 'b' 'c'
  assert_success
  assert_output $'a\nb\nc'
}

@test "to_lines: empty-string arg becomes empty line" {
  run arrays::to_lines 'a' '' 'b'
  assert_success
  assert_output $'a\n\nb'
}

@test "to_lines: arg starting with dash is treated literally" {
  run arrays::to_lines '-foo' '--bar'
  assert_success
  assert_output $'-foo\n--bar'
}

@test "to_lines: arg containing newline preserved" {
  run arrays::to_lines $'a\nb' 'c'
  assert_success
  assert_output $'a\nb\nc'
}
