#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/strings.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/misc.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/dirs.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/prompt.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/files.bash"
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

@test "diff: both arrays empty -> empty output" {
  a=()
  b=()
  mapfile -t result < <(arrays::diff a b)
  assert_equal "${#result[@]}" 0
}

@test "diff: first empty, second populated -> empty output" {
  a=()
  b=('apple' 'banana' 'cherry')
  mapfile -t result < <(arrays::diff a b)
  assert_equal "${#result[@]}" 0
}

@test "diff: second empty, first populated -> output equals first" {
  a=('apple' 'banana' 'cherry')
  b=()
  mapfile -t result < <(arrays::diff a b)
  assert_equal "${#result[@]}" 3
  assert_equal "${result[0]}" 'apple'
  assert_equal "${result[1]}" 'banana'
  assert_equal "${result[2]}" 'cherry'
}

@test "diff: identical arrays -> empty output" {
  a=('alpha' 'beta' 'gamma')
  b=('alpha' 'beta' 'gamma')
  mapfile -t result < <(arrays::diff a b)
  assert_equal "${#result[@]}" 0
}

@test "diff: no overlap -> output equals first" {
  a=('aaa' 'bbb' 'ccc')
  b=('ddd' 'eee' 'fff')
  mapfile -t result < <(arrays::diff a b)
  assert_equal "${#result[@]}" 3
  assert_equal "${result[0]}" 'aaa'
  assert_equal "${result[1]}" 'bbb'
  assert_equal "${result[2]}" 'ccc'
}

@test "diff: partial overlap -> only non-shared first elements" {
  a=('apple' 'banana' 'cherry' 'date')
  b=('banana' 'date')
  mapfile -t result < <(arrays::diff a b)
  assert_equal "${#result[@]}" 2
  assert_equal "${result[0]}" 'apple'
  assert_equal "${result[1]}" 'cherry'
}

@test "diff: single-element arrays, same element -> empty output" {
  a=('only')
  b=('only')
  mapfile -t result < <(arrays::diff a b)
  assert_equal "${#result[@]}" 0
}

@test "diff: single-element arrays, different elements -> output equals first" {
  a=('aaa')
  b=('bbb')
  mapfile -t result < <(arrays::diff a b)
  assert_equal "${#result[@]}" 1
  assert_equal "${result[0]}" 'aaa'
}

@test "diff: element in second but not first -> not in output" {
  # shellcheck disable=SC2034  # used via nameref inside arrays::diff
  a=('apple' 'cherry')
  # shellcheck disable=SC2034  # used via nameref inside arrays::diff
  b=('apple' 'banana' 'cherry')
  mapfile -t result < <(arrays::diff a b)
  assert_equal "${#result[@]}" 0
}

@test "contains: needle is the first element -> success" {
  run arrays::contains 'apple' 'apple' 'banana' 'cherry'
  assert_success
}

@test "contains: needle is a middle element -> success" {
  run arrays::contains 'banana' 'apple' 'banana' 'cherry'
  assert_success
}

@test "contains: needle is the last element -> success" {
  run arrays::contains 'cherry' 'apple' 'banana' 'cherry'
  assert_success
}

@test "contains: needle absent from a multi-element haystack -> failure" {
  run arrays::contains 'durian' 'apple' 'banana' 'cherry'
  assert_failure
}

@test "contains: empty haystack -> failure" {
  run arrays::contains 'apple'
  assert_failure
}

@test "contains: single-element haystack, matching -> success" {
  run arrays::contains 'apple' 'apple'
  assert_success
}

@test "contains: single-element haystack, non-matching -> failure" {
  run arrays::contains 'apple' 'banana'
  assert_failure
}

@test "contains: needle containing whitespace matches an identical element" {
  run arrays::contains 'red apple' 'green pear' 'red apple'
  assert_success
}

@test "contains: needle containing whitespace does not match a prefix" {
  run arrays::contains 'red apple' 'red' 'apple'
  assert_failure
}

@test "contains: glob metacharacter in the needle is compared literally" {
  # Pins the quoted right-hand side of the [[ ]] test. If the implementation
  # wrote [[ "${item}" == ${needle} ]] the '*' would pattern-match 'apple'
  # and this would wrongly succeed.
  run arrays::contains '*' 'apple' 'banana'
  assert_failure
}

@test "contains: glob metacharacter matches an identical element" {
  run arrays::contains '*' 'apple' '*'
  assert_success
}

@test "contains: empty-string needle matches an empty-string element" {
  run arrays::contains '' 'apple' ''
  assert_success
}

@test "contains: empty-string needle with no empty element -> failure" {
  run arrays::contains '' 'apple' 'banana'
  assert_failure
}

@test "contains: dies with no args" {
  run arrays::contains
  assert_failure
  assert_output --partial 'Expected at least 1 argument'
}
