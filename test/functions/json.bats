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
  run bash -c "source '${SCRIPTS_DIR}/functions.bash'; printf '%s' 'not json' | json::sort"
  assert_failure
}

@test "sort: invalid JSON fails (file)" {
  printf '%s' 'not json' > "${BATS_TEST_TMPDIR}/bad.json"
  run bash -c "source '${SCRIPTS_DIR}/functions.bash'; json::sort \"\$1\"" _ "${BATS_TEST_TMPDIR}/bad.json"
  assert_failure
}
