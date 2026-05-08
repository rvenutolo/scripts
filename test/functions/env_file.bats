#!/usr/bin/env bats

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/test/test_helper/env_file_fixture.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/files.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/strings.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/grep.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/env_file.bash"
}

# ---------- env_file::assert_var_exists ----------

@test "assert_var_exists: var present succeeds" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=value\n')"
  run env_file::assert_var_exists "${env_file}" 'KEY'
  assert_success
}

@test "assert_var_exists: var absent dies" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=value\n')"
  run env_file::assert_var_exists "${env_file}" 'MISSING'
  assert_failure
  assert_output --partial 'MISSING does not exist'
}

@test "assert_var_exists: file missing dies" {
  run env_file::assert_var_exists '/nonexistent/path' 'KEY'
  assert_failure
}

@test "assert_var_exists: var name with regex meta is rejected" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=value\n')"
  run env_file::assert_var_exists "${env_file}" 'K.Y'
  assert_failure
  assert_output --partial 'Invalid env var name'
}

@test "assert_var_exists: var name with leading digit is rejected" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=value\n')"
  run env_file::assert_var_exists "${env_file}" '1KEY'
  assert_failure
  assert_output --partial 'Invalid env var name'
}

@test "assert_var_exists: var name with hyphen is rejected" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=value\n')"
  run env_file::assert_var_exists "${env_file}" 'MY-KEY'
  assert_failure
  assert_output --partial 'Invalid env var name'
}

@test "assert_var_exists: commented line does not count as match" {
  local env_file
  env_file="$(env_file_fixture::create $'#KEY=value\n')"
  run env_file::assert_var_exists "${env_file}" 'KEY'
  assert_failure
  assert_output --partial 'KEY does not exist'
}

@test "assert_var_exists: var as substring of another var is not matched" {
  local env_file
  env_file="$(env_file_fixture::create $'BIG_KEY=value\n')"
  run env_file::assert_var_exists "${env_file}" 'KEY'
  assert_failure
  assert_output --partial 'KEY does not exist'
}

@test "assert_var_exists: var anywhere in multi-line file is matched" {
  local env_file
  env_file="$(env_file_fixture::create $'A=1\nB=2\nKEY=value\nC=3\n')"
  run env_file::assert_var_exists "${env_file}" 'KEY'
  assert_success
}

@test "assert_var_exists: dies with 0 args" {
  run env_file::assert_var_exists
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "assert_var_exists: dies with 1 arg" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=value\n')"
  run env_file::assert_var_exists "${env_file}"
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "assert_var_exists: dies with 3 args" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=value\n')"
  run env_file::assert_var_exists "${env_file}" 'KEY' 'extra'
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

# ---------- env_file::get_var_value ----------

@test "get_var_value: simple value" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=hello\n')"
  run env_file::get_var_value "${env_file}" 'KEY'
  assert_success
  assert_output 'hello'
}

@test "get_var_value: empty value" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  run env_file::get_var_value "${env_file}" 'KEY'
  assert_success
  assert_output ''
}

@test "get_var_value: value containing equals sign" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=a=b=c\n')"
  run env_file::get_var_value "${env_file}" 'KEY'
  assert_success
  assert_output 'a=b=c'
}

@test "get_var_value: value with spaces" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=hello world\n')"
  run env_file::get_var_value "${env_file}" 'KEY'
  assert_success
  assert_output 'hello world'
}

@test "get_var_value: quoted value returned literally with quotes" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY="quoted"\n')"
  run env_file::get_var_value "${env_file}" 'KEY'
  assert_success
  assert_output '"quoted"'
}

@test "get_var_value: var name with regex meta is rejected" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=value\n')"
  run env_file::get_var_value "${env_file}" 'K.Y'
  assert_failure
  assert_output --partial 'Invalid env var name'
}

@test "get_var_value: file missing dies" {
  run env_file::get_var_value '/nonexistent/path' 'KEY'
  assert_failure
}

@test "get_var_value: var missing dies via assert_var_exists chain" {
  local env_file
  env_file="$(env_file_fixture::create $'OTHER=1\n')"
  run env_file::get_var_value "${env_file}" 'KEY'
  assert_failure
  assert_output --partial 'KEY does not exist'
}

@test "get_var_value: picks correct line in multi-line file" {
  local env_file
  env_file="$(env_file_fixture::create $'A=alpha\nB=beta\nKEY=target\nC=gamma\n')"
  run env_file::get_var_value "${env_file}" 'KEY'
  assert_success
  assert_output 'target'
}

@test "get_var_value: value with leading/trailing spaces preserved" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=  spaced  \n')"
  run env_file::get_var_value "${env_file}" 'KEY'
  assert_success
  assert_output '  spaced  '
}

@test "get_var_value: dies with 0 args" {
  run env_file::get_var_value
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "get_var_value: dies with 1 arg" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=value\n')"
  run env_file::get_var_value "${env_file}"
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "get_var_value: dies with 3 args" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=value\n')"
  run env_file::get_var_value "${env_file}" 'KEY' 'extra'
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

# ---------- env_file::is_var_value_empty ----------

@test "is_var_value_empty: empty value -> true" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  run env_file::is_var_value_empty "${env_file}" 'KEY'
  assert_success
}

@test "is_var_value_empty: non-empty value -> false" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=value\n')"
  run env_file::is_var_value_empty "${env_file}" 'KEY'
  assert_failure
}

@test "is_var_value_empty: quoted-empty KEY=\"\" treated as non-empty (literal quotes)" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=""\n')"
  run env_file::is_var_value_empty "${env_file}" 'KEY'
  assert_failure
}

@test "is_var_value_empty: single-space value treated as non-empty" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY= \n')"
  run env_file::is_var_value_empty "${env_file}" 'KEY'
  assert_failure
}

@test "is_var_value_empty: var name with regex meta is rejected" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  run env_file::is_var_value_empty "${env_file}" 'K.Y'
  assert_failure
  assert_output --partial 'Invalid env var name'
}

@test "is_var_value_empty: file missing dies" {
  run env_file::is_var_value_empty '/nonexistent/path' 'KEY'
  assert_failure
}

@test "is_var_value_empty: var missing dies" {
  local env_file
  env_file="$(env_file_fixture::create $'OTHER=1\n')"
  run env_file::is_var_value_empty "${env_file}" 'KEY'
  assert_failure
  assert_output --partial 'KEY does not exist'
}

@test "is_var_value_empty: dies with 1 arg" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  run env_file::is_var_value_empty "${env_file}"
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "is_var_value_empty: dies with 3 args" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  run env_file::is_var_value_empty "${env_file}" 'KEY' 'extra'
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

# ---------- env_file::set_var_value ----------

# Helper: read back a var from a file using a fresh subshell so test
# state doesn't bleed between invocations of get/set in the same @test.
read_back() {
  bash -c "source '${SCRIPTS_DIR}/functions.bash'; env_file::get_var_value \"\$1\" \"\$2\"" _ "$1" "$2"
}

@test "set_var_value: replaces simple value" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  env_file::set_var_value "${env_file}" 'KEY' 'new'
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'new'
}

@test "set_var_value: replaces empty with non-empty" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  env_file::set_var_value "${env_file}" 'KEY' 'value'
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'value'
}

@test "set_var_value: replaces with empty value" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  env_file::set_var_value "${env_file}" 'KEY' ''
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output ''
}

@test "set_var_value: value containing equals" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  env_file::set_var_value "${env_file}" 'KEY' 'a=b=c'
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'a=b=c'
}

@test "set_var_value: value containing forward slash" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  env_file::set_var_value "${env_file}" 'KEY' '/usr/local/bin'
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output '/usr/local/bin'
}

@test "set_var_value: value containing ampersand" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  env_file::set_var_value "${env_file}" 'KEY' 'foo&bar'
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'foo&bar'
}

@test "set_var_value: value containing pipe" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  env_file::set_var_value "${env_file}" 'KEY' 'foo|bar'
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'foo|bar'
}

@test "set_var_value: value containing backslash" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  env_file::set_var_value "${env_file}" 'KEY' 'a\b'
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'a\b'
}

@test "set_var_value: value containing dollar sign" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  # Single-quoted '$VAR' is intentional: we want the literal dollar sign passed as value, not shell expansion.
  # shellcheck disable=SC2016
  env_file::set_var_value "${env_file}" 'KEY' '$VAR'
  run read_back "${env_file}" 'KEY'
  assert_success
  # Single-quoted '$VAR' is intentional: asserting the literal string was stored and retrieved, not expanded.
  # shellcheck disable=SC2016
  assert_output '$VAR'
}

@test "set_var_value: value containing double-quote" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  env_file::set_var_value "${env_file}" 'KEY' 'he said "hi"'
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'he said "hi"'
}

@test "set_var_value: newline in value is rejected" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  run env_file::set_var_value "${env_file}" 'KEY' $'line1\nline2'
  assert_failure
  assert_output --partial 'cannot contain newlines'
}

@test "set_var_value: var name with regex meta is rejected" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  run env_file::set_var_value "${env_file}" 'K.Y' 'value'
  assert_failure
  assert_output --partial 'Invalid env var name'
}

@test "set_var_value: var missing dies" {
  local env_file
  env_file="$(env_file_fixture::create $'OTHER=1\n')"
  run env_file::set_var_value "${env_file}" 'KEY' 'value'
  assert_failure
  assert_output --partial 'KEY does not exist'
}

@test "set_var_value: file missing dies" {
  run env_file::set_var_value '/nonexistent/path' 'KEY' 'value'
  assert_failure
}

@test "set_var_value: multiple matching lines are all updated" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=first\nOTHER=x\nKEY=second\n')"
  env_file::set_var_value "${env_file}" 'KEY' 'updated'
  local count
  count="$(grep --count '^KEY=updated$' "${env_file}")"
  [[ "${count}" == '2' ]]
}

@test "set_var_value: dies with 0 args" {
  run env_file::set_var_value
  assert_failure
  assert_output --partial 'Expected exactly 3 arguments'
}

@test "set_var_value: dies with 2 args" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  run env_file::set_var_value "${env_file}" 'KEY'
  assert_failure
  assert_output --partial 'Expected exactly 3 arguments'
}

@test "set_var_value: dies with 4 args" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  run env_file::set_var_value "${env_file}" 'KEY' 'value' 'extra'
  assert_failure
  assert_output --partial 'Expected exactly 3 arguments'
}

# ---------- env_file::set_var_value_if_empty ----------

@test "set_var_value_if_empty: empty -> sets" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  env_file::set_var_value_if_empty "${env_file}" 'KEY' 'new'
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'new'
}

@test "set_var_value_if_empty: non-empty -> no-op" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=existing\n')"
  env_file::set_var_value_if_empty "${env_file}" 'KEY' 'new'
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'existing'
}

@test "set_var_value_if_empty: var missing dies" {
  local env_file
  env_file="$(env_file_fixture::create $'OTHER=1\n')"
  run env_file::set_var_value_if_empty "${env_file}" 'KEY' 'new'
  assert_failure
  assert_output --partial 'KEY does not exist'
}

@test "set_var_value_if_empty: file missing dies" {
  run env_file::set_var_value_if_empty '/nonexistent/path' 'KEY' 'new'
  assert_failure
}

@test "set_var_value_if_empty: var name with regex meta is rejected" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  run env_file::set_var_value_if_empty "${env_file}" 'K.Y' 'value'
  assert_failure
  assert_output --partial 'Invalid env var name'
}

@test "set_var_value_if_empty: dies with 2 args" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  run env_file::set_var_value_if_empty "${env_file}" 'KEY'
  assert_failure
  assert_output --partial 'Expected exactly 3 arguments'
}

@test "set_var_value_if_empty: dies with 4 args" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  run env_file::set_var_value_if_empty "${env_file}" 'KEY' 'value' 'extra'
  assert_failure
  assert_output --partial 'Expected exactly 3 arguments'
}
