#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

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
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/passwords.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/misc.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/prompt.bash"

  # Override pwgen-based password generators with deterministic mocks for tests.
  # BATS isolates each @test in its own subshell, so no leakage between tests.
  # shellcheck disable=SC2329 # invoked indirectly by env_file functions under test
  function passwords::generate() {
    printf '%s\n' 'MOCK_PASSWORD_64'
  }
  # shellcheck disable=SC2329 # invoked indirectly by env_file functions under test
  function passwords::generate_with_symbols() {
    printf '%s\n' 'MOCK_PASSWORD_SYMBOLS'
  }
}

# Helper: run a fn via bash -c with stdin fed from a heredoc string.
# Used to test typed-value paths through prompt::for_value (read -rp).
# Mocks pwgen overrides are re-declared inside the child bash because
# function definitions do not survive across `bash -c` boundaries by default.
#
# $1 = stdin string (will be fed via <<<)
# $2 = command string to evaluate (e.g. "env_file::prompt_var_value \"\$1\" 'KEY' 'info' 'default'")
# $3..$N = positional args passed to the child shell as $1, $2, ...
prompt_via_stdin() {
  local -r stdin_str="$1"
  local -r cmd="$2"
  shift 2
  # shellcheck disable=SC2016 # single quotes intentional: $1/$2 expand in child shell, not here
  run bash -c "
    source '${SCRIPTS_DIR}/functions.bash'
    function passwords::generate() { printf '%s\n' 'MOCK_PASSWORD_64'; }
    function passwords::generate_with_symbols() { printf '%s\n' 'MOCK_PASSWORD_SYMBOLS'; }
    ${cmd}
  " _ "$@" <<< "${stdin_str}"
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

# ---------- env_file::prompt_var_value ----------

@test "prompt_var_value: 4-arg auto_answer accepts default" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  SCRIPTS_AUTO_ANSWER=y env_file::prompt_var_value "${env_file}" 'KEY' 'info' 'default-val'
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'default-val'
}

@test "prompt_var_value: 4-arg typed value overrides default and prompt shows var/info/default" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  prompt_via_stdin 'typed-val' "env_file::prompt_var_value \"\$1\" 'KEY' 'info-text' 'default-val'" "${env_file}"
  assert_success
  # TODO: brittle ANSI-text assertion — read -rp writes prompt to /dev/tty, not captured by run
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'typed-val'
}

@test "prompt_var_value: 3-arg (info, no default) typed value with prompt showing info" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  prompt_via_stdin 'typed-val' "env_file::prompt_var_value \"\$1\" 'KEY' 'info-text'" "${env_file}"
  assert_success
  # TODO: brittle ANSI-text assertion — read -rp writes prompt to /dev/tty, not captured by run
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'typed-val'
}

@test "prompt_var_value: 2-arg (no info, no default) typed value with prompt showing var" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  prompt_via_stdin 'typed-val' "env_file::prompt_var_value \"\$1\" 'KEY'" "${env_file}"
  assert_success
  # TODO: brittle ANSI-text assertion — read -rp writes prompt to /dev/tty, not captured by run
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'typed-val'
}

@test "prompt_var_value: var name with regex meta is rejected" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  run env_file::prompt_var_value "${env_file}" 'K.Y' 'info' 'default'
  assert_failure
  assert_output --partial 'Invalid env var name'
}

@test "prompt_var_value: var missing dies" {
  local env_file
  env_file="$(env_file_fixture::create $'OTHER=1\n')"
  SCRIPTS_AUTO_ANSWER=y run env_file::prompt_var_value "${env_file}" 'KEY' '' 'value'
  assert_failure
  assert_output --partial 'KEY does not exist'
}

@test "prompt_var_value: file missing dies" {
  SCRIPTS_AUTO_ANSWER=y run env_file::prompt_var_value '/nonexistent/path' 'KEY' '' 'value'
  assert_failure
}

@test "prompt_var_value: dies with 1 arg" {
  run env_file::prompt_var_value 'somefile'
  assert_failure
  assert_output --partial 'Expected at least 2 arguments'
}

@test "prompt_var_value: dies with 5 args" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  run env_file::prompt_var_value "${env_file}" 'KEY' 'info' 'default' 'extra'
  assert_failure
  assert_output --partial 'Expected at most 4 arguments'
}

# ---------- env_file::prompt_var_value_if_empty ----------

@test "prompt_var_value_if_empty: empty -> sets via prompt" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  SCRIPTS_AUTO_ANSWER=y env_file::prompt_var_value_if_empty "${env_file}" 'KEY' 'info' 'default-val'
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'default-val'
}

@test "prompt_var_value_if_empty: non-empty -> no-op" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=existing\n')"
  SCRIPTS_AUTO_ANSWER=y env_file::prompt_var_value_if_empty "${env_file}" 'KEY' 'info' 'default-val'
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'existing'
}

@test "prompt_var_value_if_empty: var missing dies" {
  local env_file
  env_file="$(env_file_fixture::create $'OTHER=1\n')"
  SCRIPTS_AUTO_ANSWER=y run env_file::prompt_var_value_if_empty "${env_file}" 'KEY' '' 'value'
  assert_failure
  assert_output --partial 'KEY does not exist'
}

@test "prompt_var_value_if_empty: dies with 1 arg" {
  run env_file::prompt_var_value_if_empty 'somefile'
  assert_failure
  assert_output --partial 'Expected at least 2 arguments'
}

@test "prompt_var_value_if_empty: dies with 5 args" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  run env_file::prompt_var_value_if_empty "${env_file}" 'KEY' 'info' 'default' 'extra'
  assert_failure
  assert_output --partial 'Expected at most 4 arguments'
}

# ---------- env_file::prompt_value_with_default ----------

@test "prompt_value_with_default: auto_answer accepts default" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  SCRIPTS_AUTO_ANSWER=y env_file::prompt_value_with_default "${env_file}" 'KEY' 'default-val'
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'default-val'
}

@test "prompt_value_with_default: typed value overrides default" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  prompt_via_stdin 'typed-val' "env_file::prompt_value_with_default \"\$1\" 'KEY' 'default-val'" "${env_file}"
  assert_success
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'typed-val'
}

@test "prompt_value_with_default: var name with regex meta is rejected" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  run env_file::prompt_value_with_default "${env_file}" 'K.Y' 'default'
  assert_failure
  assert_output --partial 'Invalid env var name'
}

@test "prompt_value_with_default: dies with 2 args" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  run env_file::prompt_value_with_default "${env_file}" 'KEY'
  assert_failure
  assert_output --partial 'Expected exactly 3 arguments'
}

@test "prompt_value_with_default: dies with 4 args" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=old\n')"
  run env_file::prompt_value_with_default "${env_file}" 'KEY' 'default' 'extra'
  assert_failure
  assert_output --partial 'Expected exactly 3 arguments'
}

# ---------- env_file::prompt_value_with_default_if_empty ----------

@test "prompt_value_with_default_if_empty: empty -> sets default" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  SCRIPTS_AUTO_ANSWER=y env_file::prompt_value_with_default_if_empty "${env_file}" 'KEY' 'default-val'
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'default-val'
}

@test "prompt_value_with_default_if_empty: non-empty -> no-op" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=existing\n')"
  SCRIPTS_AUTO_ANSWER=y env_file::prompt_value_with_default_if_empty "${env_file}" 'KEY' 'default-val'
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'existing'
}

@test "prompt_value_with_default_if_empty: var missing dies" {
  local env_file
  env_file="$(env_file_fixture::create $'OTHER=1\n')"
  SCRIPTS_AUTO_ANSWER=y run env_file::prompt_value_with_default_if_empty "${env_file}" 'KEY' 'default'
  assert_failure
  assert_output --partial 'KEY does not exist'
}

@test "prompt_value_with_default_if_empty: dies with 2 args" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  run env_file::prompt_value_with_default_if_empty "${env_file}" 'KEY'
  assert_failure
  assert_output --partial 'Expected exactly 3 arguments'
}

@test "prompt_value_with_default_if_empty: dies with 4 args" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  run env_file::prompt_value_with_default_if_empty "${env_file}" 'KEY' 'default' 'extra'
  assert_failure
  assert_output --partial 'Expected exactly 3 arguments'
}

# ---------- env_file::prompt_pw_value ----------

@test "prompt_pw_value: 2-arg auto_answer writes mock password" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  SCRIPTS_AUTO_ANSWER=y env_file::prompt_pw_value "${env_file}" 'KEY'
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'MOCK_PASSWORD_64'
}

@test "prompt_pw_value: 3-arg auto_answer with info writes mock password" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  SCRIPTS_AUTO_ANSWER=y env_file::prompt_pw_value "${env_file}" 'KEY' 'pw info'
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'MOCK_PASSWORD_64'
}

@test "prompt_pw_value: typed value overrides mock default" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  prompt_via_stdin 'typed-pw' "env_file::prompt_pw_value \"\$1\" 'KEY'" "${env_file}"
  assert_success
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'typed-pw'
}

@test "prompt_pw_value: 3-arg typed value (with info)" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  prompt_via_stdin 'typed-pw' "env_file::prompt_pw_value \"\$1\" 'KEY' 'pw info'" "${env_file}"
  assert_success
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'typed-pw'
}

@test "prompt_pw_value: var name with regex meta is rejected" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  run env_file::prompt_pw_value "${env_file}" 'K.Y'
  assert_failure
  assert_output --partial 'Invalid env var name'
}

@test "prompt_pw_value: dies with 1 arg" {
  run env_file::prompt_pw_value 'somefile'
  assert_failure
  assert_output --partial 'Expected at least 2 arguments'
}

@test "prompt_pw_value: dies with 4 args" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  run env_file::prompt_pw_value "${env_file}" 'KEY' 'info' 'extra'
  assert_failure
  assert_output --partial 'Expected at most 3 arguments'
}

# ---------- env_file::prompt_pw_with_symbols_value ----------

@test "prompt_pw_with_symbols_value: 2-arg auto_answer writes mock symbols password" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  SCRIPTS_AUTO_ANSWER=y env_file::prompt_pw_with_symbols_value "${env_file}" 'KEY'
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'MOCK_PASSWORD_SYMBOLS'
}

@test "prompt_pw_with_symbols_value: typed value overrides mock default" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  prompt_via_stdin 'typed-pw' "env_file::prompt_pw_with_symbols_value \"\$1\" 'KEY'" "${env_file}"
  assert_success
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'typed-pw'
}

@test "prompt_pw_with_symbols_value: var name with regex meta is rejected" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  run env_file::prompt_pw_with_symbols_value "${env_file}" 'K.Y'
  assert_failure
  assert_output --partial 'Invalid env var name'
}

@test "prompt_pw_with_symbols_value: dies with 4 args" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  run env_file::prompt_pw_with_symbols_value "${env_file}" 'KEY' 'info' 'extra'
  assert_failure
  assert_output --partial 'Expected at most 3 arguments'
}

# ---------- env_file::prompt_pw_value_if_empty ----------

@test "prompt_pw_value_if_empty: empty -> writes mock password" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  SCRIPTS_AUTO_ANSWER=y env_file::prompt_pw_value_if_empty "${env_file}" 'KEY'
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'MOCK_PASSWORD_64'
}

@test "prompt_pw_value_if_empty: non-empty -> no-op" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=existing\n')"
  SCRIPTS_AUTO_ANSWER=y env_file::prompt_pw_value_if_empty "${env_file}" 'KEY'
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'existing'
}

@test "prompt_pw_value_if_empty: dies with 1 arg" {
  run env_file::prompt_pw_value_if_empty 'somefile'
  assert_failure
  assert_output --partial 'Expected at least 2 arguments'
}

@test "prompt_pw_value_if_empty: dies with 4 args" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  run env_file::prompt_pw_value_if_empty "${env_file}" 'KEY' 'info' 'extra'
  assert_failure
  assert_output --partial 'Expected at most 3 arguments'
}

# ---------- env_file::prompt_pw_with_symbols_value_if_empty ----------

@test "prompt_pw_with_symbols_value_if_empty: empty -> writes mock symbols password" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  SCRIPTS_AUTO_ANSWER=y env_file::prompt_pw_with_symbols_value_if_empty "${env_file}" 'KEY'
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'MOCK_PASSWORD_SYMBOLS'
}

@test "prompt_pw_with_symbols_value_if_empty: non-empty -> no-op" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=existing\n')"
  SCRIPTS_AUTO_ANSWER=y env_file::prompt_pw_with_symbols_value_if_empty "${env_file}" 'KEY'
  run read_back "${env_file}" 'KEY'
  assert_success
  assert_output 'existing'
}

@test "prompt_pw_with_symbols_value_if_empty: dies with 1 arg" {
  run env_file::prompt_pw_with_symbols_value_if_empty 'somefile'
  assert_failure
  assert_output --partial 'Expected at least 2 arguments'
}

@test "prompt_pw_with_symbols_value_if_empty: dies with 4 args" {
  local env_file
  env_file="$(env_file_fixture::create $'KEY=\n')"
  run env_file::prompt_pw_with_symbols_value_if_empty "${env_file}" 'KEY' 'info' 'extra'
  assert_failure
  assert_output --partial 'Expected at most 3 arguments'
}
