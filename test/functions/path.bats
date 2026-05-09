#!/usr/bin/env bats

# shellcheck disable=SC2123 # tests intentionally mutate PATH to exercise path::* helpers

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/path.bash"
  # Capture original PATH so teardown can restore it. Tests that mutate PATH
  # to a restricted value (e.g. PATH='') can break BATS's own cleanup (rm,
  # etc.) unless we restore a usable PATH after each test.
  ORIGINAL_PATH="${PATH}"
}

teardown() {
  PATH="${ORIGINAL_PATH}"
}

# ---------- path::remove ----------

@test "remove: target at start" {
  PATH='/opt/x:/usr/bin:/bin'
  path::remove '/opt/x'
  [[ "${PATH}" == '/usr/bin:/bin' ]]
}

@test "remove: target in middle" {
  PATH='/usr/bin:/opt/x:/bin'
  path::remove '/opt/x'
  [[ "${PATH}" == '/usr/bin:/bin' ]]
}

@test "remove: target at end" {
  PATH='/usr/bin:/bin:/opt/x'
  path::remove '/opt/x'
  [[ "${PATH}" == '/usr/bin:/bin' ]]
}

@test "remove: target absent -> PATH unchanged" {
  PATH='/usr/bin:/bin'
  path::remove '/opt/x'
  [[ "${PATH}" == '/usr/bin:/bin' ]]
}

@test "remove: only entry -> PATH empty" {
  # path::remove short-circuits awk/sed when PATH equals exactly the target,
  # so setting PATH to only the target is safe — no tool lookup occurs.
  PATH='/opt/x'
  path::remove '/opt/x'
  [[ "${PATH}" == '' ]]
}

@test "remove: multiple occurrences all stripped" {
  PATH='/opt/x:/usr/bin:/opt/x:/bin:/opt/x'
  path::remove '/opt/x'
  [[ "${PATH}" == '/usr/bin:/bin' ]]
}

@test "remove: partial-match prefix is NOT removed" {
  PATH='/opt/xy:/opt/x:/usr/bin'
  path::remove '/opt/x'
  [[ "${PATH}" == '/opt/xy:/usr/bin' ]]
}

@test "remove: dies with no args" {
  run path::remove
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- path::append ----------

@test "append: new entry added at end" {
  PATH='/usr/bin:/bin'
  path::append '/opt/x'
  [[ "${PATH}" == '/usr/bin:/bin:/opt/x' ]]
}

@test "append: existing entry moves to end (no duplicate)" {
  PATH='/opt/x:/usr/bin:/bin'
  path::append '/opt/x'
  [[ "${PATH}" == '/usr/bin:/bin:/opt/x' ]]
}

@test "append: empty PATH -> just the entry, no leading colon" {
  # path::append short-circuits path::remove when PATH is empty, so no
  # awk/sed lookup occurs and setting PATH='' is safe here.
  PATH=''
  path::append '/opt/x'
  [[ "${PATH}" == '/opt/x' ]]
}

# ---------- path::prepend ----------

@test "prepend: new entry added at start" {
  PATH='/usr/bin:/bin'
  path::prepend '/opt/x'
  [[ "${PATH}" == '/opt/x:/usr/bin:/bin' ]]
}

@test "prepend: existing entry moves to start (no duplicate)" {
  PATH='/usr/bin:/opt/x:/bin'
  path::prepend '/opt/x'
  [[ "${PATH}" == '/opt/x:/usr/bin:/bin' ]]
}

@test "prepend: empty PATH -> just the entry, no trailing colon" {
  # path::prepend short-circuits path::remove when PATH is empty, so no
  # awk/sed lookup occurs and setting PATH='' is safe here.
  PATH=''
  path::prepend '/opt/x'
  [[ "${PATH}" == '/opt/x' ]]
}
