#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${REPO_DIR}/test/test_helper/dual_mode.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/yaml.bash"
}

@test "to_json: single key via stdin" {
  dual_mode::assert_stdin 'yaml::to_json' 'a: 1' '{
  "a": 1
}'
}

@test "to_json: single key via file" {
  dual_mode::assert_file 'yaml::to_json' 'a: 1' '{
  "a": 1
}'
}

@test "to_json: nested mapping via stdin" {
  dual_mode::assert_stdin 'yaml::to_json' \
    'b:
  d: 4
  c: 3
a: 1' \
    '{
  "b": {
    "d": 4,
    "c": 3
  },
  "a": 1
}'
}

@test "to_json: preserves key order (does not sort)" {
  dual_mode::assert_stdin 'yaml::to_json' 'b: 2
a: 1' '{
  "b": 2,
  "a": 1
}'
}

@test "to_json: empty input yields null via stdin" {
  dual_mode::assert_stdin 'yaml::to_json' '' 'null'
}

@test "to_json: sequence/array via stdin" {
  dual_mode::assert_stdin 'yaml::to_json' '- 1
- 2' '[
  1,
  2
]'
}

@test "to_json: dies with 2 args" {
  run bash -c "source '${SCRIPTS_DIR}/.functions.bash'; yaml::to_json a b"
  assert_failure
}

@test "to_json: invalid YAML fails (stdin)" {
  run bash -c "source '${SCRIPTS_DIR}/.functions.bash'; printf '%s' ': : :' | yaml::to_json"
  assert_failure
}

@test "to_json: invalid YAML fails (file)" {
  printf '%s' ': : :' > "${BATS_TEST_TMPDIR}/bad.yaml"
  run bash -c "source '${SCRIPTS_DIR}/.functions.bash'; yaml::to_json \"\$1\"" _ "${BATS_TEST_TMPDIR}/bad.yaml"
  assert_failure
}

@test "from_json: single key via stdin" {
  dual_mode::assert_stdin 'yaml::from_json' '{"a":1}' 'a: 1'
}

@test "from_json: single key via file" {
  dual_mode::assert_file 'yaml::from_json' '{"a":1}' 'a: 1'
}

@test "from_json: nested object via stdin" {
  dual_mode::assert_stdin 'yaml::from_json' '{"b":{"d":4,"c":3},"a":1}' 'b:
  d: 4
  c: 3
a: 1'
}

@test "from_json: dies with 2 args" {
  run bash -c "source '${SCRIPTS_DIR}/.functions.bash'; yaml::from_json a b"
  assert_failure
}

@test "from_json: invalid JSON fails (stdin)" {
  run bash -c "source '${SCRIPTS_DIR}/.functions.bash'; printf '%s' 'not json' | yaml::from_json"
  assert_failure
}

@test "from_json: invalid JSON fails (file)" {
  printf '%s' 'not json' > "${BATS_TEST_TMPDIR}/bad.json"
  run bash -c "source '${SCRIPTS_DIR}/.functions.bash'; yaml::from_json \"\$1\"" _ "${BATS_TEST_TMPDIR}/bad.json"
  assert_failure
}

@test "round-trip json -> yaml -> json is stable via stdin" {
  run bash -c "source '${SCRIPTS_DIR}/.functions.bash'; printf '%s' '{\"a\":1,\"b\":{\"c\":2}}' | yaml::from_json | yaml::to_json"
  assert_success
  assert_output '{
  "a": 1,
  "b": {
    "c": 2
  }
}'
}
