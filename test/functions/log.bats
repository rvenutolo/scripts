#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # log.bash already sourced by common
}

# ---------- log::log ----------

@test "log::log: writes message to stderr with green ANSI" {
  run --separate-stderr log::log 'hello world'
  assert_success
  [[ -z "${output}" ]]
  [[ "${stderr}" == *'hello world'* ]]
  [[ "${stderr}" == *$'\033[0;32m'* ]]
  [[ "${stderr}" == *$'\033[0m'* ]]
}

@test "log::log: includes time prefix HH:MM:SS" {
  run --separate-stderr log::log 'msg'
  assert_success
  [[ "${stderr}" =~ \[[0-9]{2}:[0-9]{2}:[0-9]{2} ]]
}

@test "log::log: joins multiple args with spaces" {
  run --separate-stderr log::log 'foo' 'bar' 'baz'
  assert_success
  [[ "${stderr}" == *'foo bar baz'* ]]
}

# ---------- log::with_date ----------

@test "log::with_date: includes full date YYYY-MM-DD" {
  run --separate-stderr log::with_date 'msg'
  assert_success
  [[ "${stderr}" =~ \[[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2} ]]
  [[ "${stderr}" == *'msg'* ]]
  [[ "${stderr}" == *$'\033[0;32m'* ]]
}

# ---------- log::warn ----------

@test "log::warn: writes WARN to stderr with yellow ANSI" {
  run --separate-stderr log::warn 'careful'
  assert_success
  [[ "${stderr}" == *'WARN: careful'* ]]
  [[ "${stderr}" == *$'\033[0;33m'* ]]
}

# ---------- log::die ----------

@test "log::die: exits 1 with red DIE message on stderr" {
  run --separate-stderr log::die 'something broke'
  assert_failure
  [[ "${status}" -eq 1 ]]
  [[ "${stderr}" == *'DIE: something broke'* ]]
  [[ "${stderr}" == *$'\033[0;31m'* ]]
}

@test "log::die: includes caller context (source:func:line)" {
  call_die_helper() { log::die 'boom'; }
  run --separate-stderr call_die_helper
  assert_failure
  [[ "${stderr}" == *'call_die_helper'* ]]
}

# ---------- log::_err_trap_handler ----------

@test "_err_trap_handler: prints exit/line/cmd in red to stderr" {
  run --separate-stderr log::_err_trap_handler 7 42 'false'
  assert_success
  [[ "${stderr}" == *'ERROR: line 42 (exit 7): false'* ]]
  [[ "${stderr}" == *$'\033[0;31m'* ]]
}

@test "_err_trap_handler: dies with 0 args" {
  run log::_err_trap_handler
  assert_failure
  assert_output --partial 'Expected exactly 3 arguments'
}

@test "_err_trap_handler: dies with 2 args" {
  run log::_err_trap_handler 1 2
  assert_failure
  assert_output --partial 'Expected exactly 3 arguments'
}

@test "_err_trap_handler: dies with 4 args" {
  run log::_err_trap_handler 1 2 3 4
  assert_failure
  assert_output --partial 'Expected exactly 3 arguments'
}

# ---------- log::enable_err_trap ----------

@test "enable_err_trap: failing cmd in subshell triggers ERROR line" {
  run bash -c "
    set -Eeuo pipefail
    source '${SCRIPTS_DIR}/.functions.bash'
    log::enable_err_trap
    false
    echo unreachable
  "
  assert_failure
  [[ "${output}" != *'unreachable'* ]]
  [[ "${output}" == *'ERROR: line'* ]]
  [[ "${output}" == *'false'* ]]
}

@test "enable_err_trap: dies with args" {
  run log::enable_err_trap 'extra'
  assert_failure
  assert_output --partial 'Expected no arguments'
}
