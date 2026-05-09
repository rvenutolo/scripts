#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/dirs.bash"
}

# ---------- dirs::exists ----------

@test "exists: existing dir -> true" {
  mkdir --parents "${BATS_TEST_TMPDIR}/somedir"
  run dirs::exists "${BATS_TEST_TMPDIR}/somedir"
  assert_success
}

@test "exists: nonexistent path -> false" {
  run dirs::exists "${BATS_TEST_TMPDIR}/nope"
  assert_failure
}

@test "exists: regular file -> false" {
  : > "${BATS_TEST_TMPDIR}/afile"
  run dirs::exists "${BATS_TEST_TMPDIR}/afile"
  assert_failure
}

@test "exists: symlink to dir -> true" {
  mkdir --parents "${BATS_TEST_TMPDIR}/realdir"
  ln --symbolic "${BATS_TEST_TMPDIR}/realdir" "${BATS_TEST_TMPDIR}/linkdir"
  run dirs::exists "${BATS_TEST_TMPDIR}/linkdir"
  assert_success
}

@test "exists: broken symlink -> false" {
  ln --symbolic "${BATS_TEST_TMPDIR}/missing" "${BATS_TEST_TMPDIR}/broken"
  run dirs::exists "${BATS_TEST_TMPDIR}/broken"
  assert_failure
}

@test "exists: dies with 0 args" {
  run dirs::exists
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "exists: dies with 2 args" {
  run dirs::exists 'a' 'b'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- dirs::assert_exists ----------

@test "assert_exists: existing dir -> silent success" {
  mkdir --parents "${BATS_TEST_TMPDIR}/somedir"
  run dirs::assert_exists "${BATS_TEST_TMPDIR}/somedir"
  assert_success
  assert_output ''
}

@test "assert_exists: nonexistent -> dies" {
  run dirs::assert_exists "${BATS_TEST_TMPDIR}/nope"
  assert_failure
  assert_output --partial 'does not exist'
}

@test "assert_exists: regular file -> dies" {
  : > "${BATS_TEST_TMPDIR}/afile"
  run dirs::assert_exists "${BATS_TEST_TMPDIR}/afile"
  assert_failure
  assert_output --partial 'does not exist'
}

@test "assert_exists: dies with 0 args" {
  run dirs::assert_exists
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- dirs::create ----------

@test "create: nonexistent dir is created" {
  local target="${BATS_TEST_TMPDIR}/newdir"
  dirs::create "${target}"
  [[ -d "${target}" ]]
}

@test "create: existing dir is idempotent" {
  local target="${BATS_TEST_TMPDIR}/existing"
  mkdir --parents "${target}"
  dirs::create "${target}"
  [[ -d "${target}" ]]
}

@test "create: nested missing parents are created" {
  local target="${BATS_TEST_TMPDIR}/a/b/c/d"
  dirs::create "${target}"
  [[ -d "${target}" ]]
}

@test "create: multiple targets all created" {
  dirs::create "${BATS_TEST_TMPDIR}/x" "${BATS_TEST_TMPDIR}/y" "${BATS_TEST_TMPDIR}/z"
  [[ -d "${BATS_TEST_TMPDIR}/x" ]]
  [[ -d "${BATS_TEST_TMPDIR}/y" ]]
  [[ -d "${BATS_TEST_TMPDIR}/z" ]]
}

@test "create: emits Creating/Created log lines on stderr" {
  run --separate-stderr dirs::create "${BATS_TEST_TMPDIR}/loud"
  assert_success
  [[ "${stderr}" == *'Creating'* ]]
  [[ "${stderr}" == *'Created'* ]]
}

@test "create: existing dir produces no log lines" {
  mkdir --parents "${BATS_TEST_TMPDIR}/quiet"
  run --separate-stderr dirs::create "${BATS_TEST_TMPDIR}/quiet"
  assert_success
  [[ "${stderr}" != *'Creating'* ]]
}

@test "create: dies with 0 args" {
  run dirs::create
  assert_failure
  assert_output --partial 'Expected at least 1 argument'
}

# ---------- dirs::root_create ----------

@test "root_create: skipped (requires sudo, Phase G)" {
  skip 'requires sudo (Phase G)'
}
