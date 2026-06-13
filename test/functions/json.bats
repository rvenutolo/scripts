#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/test/test_helper/dual_mode.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/json.bash"
}

@test "sort: empty object via stdin" {
  dual_mode::assert_stdin 'json::sort' '{}' '{}'
}

@test "sort: empty object via file" {
  dual_mode::assert_file 'json::sort' '{}' '{}'
}

@test "sort: single key via stdin" {
  dual_mode::assert_stdin 'json::sort' '{"a":1}' '{
  "a": 1
}'
}

@test "sort: single key via file" {
  dual_mode::assert_file 'json::sort' '{"a":1}' '{
  "a": 1
}'
}

@test "sort: two keys reordered via stdin" {
  dual_mode::assert_stdin 'json::sort' '{"b":2,"a":1}' '{
  "a": 1,
  "b": 2
}'
}

@test "sort: two keys reordered via file" {
  dual_mode::assert_file 'json::sort' '{"b":2,"a":1}' '{
  "a": 1,
  "b": 2
}'
}

@test "sort: nested objects sorted recursively via stdin" {
  dual_mode::assert_stdin 'json::sort' \
    '{"b":{"d":4,"c":3},"a":1}' \
    '{
  "a": 1,
  "b": {
    "c": 3,
    "d": 4
  }
}'
}

@test "sort: nested objects sorted recursively via file" {
  dual_mode::assert_file 'json::sort' \
    '{"b":{"d":4,"c":3},"a":1}' \
    '{
  "a": 1,
  "b": {
    "c": 3,
    "d": 4
  }
}'
}

@test "sort: array preserves element order, sorts inner objects via stdin" {
  dual_mode::assert_stdin 'json::sort' \
    '[{"b":2,"a":1},{"d":4,"c":3}]' \
    '[
  {
    "a": 1,
    "b": 2
  },
  {
    "c": 3,
    "d": 4
  }
]'
}

@test "sort: already-sorted input is idempotent via stdin" {
  dual_mode::assert_stdin 'json::sort' '{"a":1,"b":2}' '{
  "a": 1,
  "b": 2
}'
}

@test "sort: invalid JSON fails (stdin)" {
  run bash -c "source '${SCRIPTS_DIR}/.functions.bash'; printf '%s' 'not json' | json::sort"
  assert_failure
}

@test "sort: invalid JSON fails (file)" {
  printf '%s' 'not json' > "${BATS_TEST_TMPDIR}/bad.json"
  run bash -c "source '${SCRIPTS_DIR}/.functions.bash'; json::sort \"\$1\"" _ "${BATS_TEST_TMPDIR}/bad.json"
  assert_failure
}

@test "key_paths: leaf paths dotted, sorted via stdin" {
  dual_mode::assert_stdin 'json::key_paths' '{"b":2,"a":{"d":4,"c":3}}' '.a.c
.a.d
.b'
}

@test "key_paths: leaf paths dotted, sorted via file" {
  dual_mode::assert_file 'json::key_paths' '{"b":2,"a":{"d":4,"c":3}}' '.a.c
.a.d
.b'
}

@test "key_paths: array indices use [N] notation via stdin" {
  dual_mode::assert_stdin 'json::key_paths' '{"list":[{"x":1,"y":2}]}' '.list[0].x
.list[0].y'
}

@test "key_paths: only leaf paths, no intermediate container paths" {
  dual_mode::assert_stdin 'json::key_paths' '{"a":{"b":{"c":1}}}' '.a.b.c'
}

@test "key_paths: top-level array indices via stdin" {
  dual_mode::assert_stdin 'json::key_paths' '[{"a":1},{"a":2}]' '[0].a
[1].a'
}

@test "key_paths: empty object yields no output via stdin" {
  run bash -c "source '${SCRIPTS_DIR}/.functions.bash'; printf '%s' '{}' | json::key_paths"
  assert_success
  assert_output ''
}

@test "key_paths: invalid JSON fails (stdin)" {
  run bash -c "source '${SCRIPTS_DIR}/.functions.bash'; printf '%s' 'not json' | json::key_paths"
  assert_failure
}

@test "key_paths: invalid JSON fails (file)" {
  printf '%s' 'not json' > "${BATS_TEST_TMPDIR}/bad.json"
  run bash -c "source '${SCRIPTS_DIR}/.functions.bash'; json::key_paths \"\$1\"" _ "${BATS_TEST_TMPDIR}/bad.json"
  assert_failure
}

@test "key_paths: dies with 2 args" {
  run bash -c "source '${SCRIPTS_DIR}/.functions.bash'; json::key_paths a b"
  assert_failure
}

@test "key_paths: null and false leaves omitted, true listed via stdin" {
  dual_mode::assert_stdin 'json::key_paths' '{"a":null,"b":true,"c":false}' '.b'
}

@test "key_paths: truthy scalars (0, empty string) listed; falsy omitted via stdin" {
  dual_mode::assert_stdin 'json::key_paths' '{"a":null,"b":true,"c":false,"d":0,"e":"","f":1}' '.b
.d
.e
.f'
}

@test "key_paths: array indices sort lexicographically via stdin" {
  dual_mode::assert_stdin 'json::key_paths' '{"a":[1,1,1,1,1,1,1,1,1,1,1,1]}' '.a[0]
.a[10]
.a[11]
.a[1]
.a[2]
.a[3]
.a[4]
.a[5]
.a[6]
.a[7]
.a[8]
.a[9]'
}
