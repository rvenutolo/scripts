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

# ---------- root_create (Phase G) ----------

setup_dirs_root_helpers() {
  load '../test_helper/path_shim'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/test/test_helper/cli_shim.bash"
  cli_shim::install_passthrough_sudo
}

@test "root_create: creates dir via sudo passthrough" {
  setup_dirs_root_helpers
  local target="${BATS_TEST_TMPDIR}/new/nested/dir"
  run dirs::root_create "${target}"
  assert_success
  [[ -d "${target}" ]]
  assert_output --partial "Creating ${target}"
  assert_output --partial "Created ${target}"
}

@test "root_create: skips existing dir" {
  setup_dirs_root_helpers
  local target="${BATS_TEST_TMPDIR}/exists"
  mkdir --parents "${target}"
  run dirs::root_create "${target}"
  assert_success
  refute_output --partial 'Creating'
}

@test "root_create: creates multiple dirs" {
  setup_dirs_root_helpers
  local a="${BATS_TEST_TMPDIR}/a"
  local b="${BATS_TEST_TMPDIR}/b"
  run dirs::root_create "${a}" "${b}"
  assert_success
  [[ -d "${a}" && -d "${b}" ]]
}

@test "root_create: dies with no args" {
  run dirs::root_create
  assert_failure
  assert_output --partial 'Expected at least 1 argument'
}

# ---------- dirs::is_personal_project ----------

setup_personal_project() {
  PERSONAL_PROJECTS_DIR="${BATS_TEST_TMPDIR}/personal"
  mkdir --parents "${PERSONAL_PROJECTS_DIR}"
  export PERSONAL_PROJECTS_DIR
}

@test "is_personal_project: PERSONAL_PROJECTS_DIR itself -> true" {
  setup_personal_project
  run dirs::is_personal_project "${PERSONAL_PROJECTS_DIR}"
  assert_success
}

@test "is_personal_project: subdir of PERSONAL_PROJECTS_DIR -> true" {
  setup_personal_project
  mkdir --parents "${PERSONAL_PROJECTS_DIR}/repo"
  run dirs::is_personal_project "${PERSONAL_PROJECTS_DIR}/repo"
  assert_success
}

@test "is_personal_project: deeply nested subdir -> true" {
  setup_personal_project
  mkdir --parents "${PERSONAL_PROJECTS_DIR}/a/b/c/d"
  run dirs::is_personal_project "${PERSONAL_PROJECTS_DIR}/a/b/c/d"
  assert_success
}

@test "is_personal_project: sibling dir -> false" {
  setup_personal_project
  mkdir --parents "${BATS_TEST_TMPDIR}/work"
  run dirs::is_personal_project "${BATS_TEST_TMPDIR}/work"
  assert_failure
}

@test "is_personal_project: parent dir -> false" {
  setup_personal_project
  run dirs::is_personal_project "${BATS_TEST_TMPDIR}"
  assert_failure
}

@test "is_personal_project: dir with shared prefix but not subdir -> false" {
  setup_personal_project
  mkdir --parents "${PERSONAL_PROJECTS_DIR}-other"
  run dirs::is_personal_project "${PERSONAL_PROJECTS_DIR}-other"
  assert_failure
}

@test "is_personal_project: symlink into PERSONAL_PROJECTS_DIR -> true" {
  setup_personal_project
  mkdir --parents "${PERSONAL_PROJECTS_DIR}/real"
  ln --symbolic "${PERSONAL_PROJECTS_DIR}/real" "${BATS_TEST_TMPDIR}/link"
  run dirs::is_personal_project "${BATS_TEST_TMPDIR}/link"
  assert_success
}

@test "is_personal_project: symlink outside PERSONAL_PROJECTS_DIR -> false" {
  setup_personal_project
  mkdir --parents "${BATS_TEST_TMPDIR}/external"
  ln --symbolic "${BATS_TEST_TMPDIR}/external" "${PERSONAL_PROJECTS_DIR}/link"
  run dirs::is_personal_project "${PERSONAL_PROJECTS_DIR}/link"
  assert_failure
}

@test "is_personal_project: nonexistent path under PERSONAL_PROJECTS_DIR -> true" {
  setup_personal_project
  run dirs::is_personal_project "${PERSONAL_PROJECTS_DIR}/nope/never/existed"
  assert_success
}

@test "is_personal_project: nonexistent path outside PERSONAL_PROJECTS_DIR -> false" {
  setup_personal_project
  run dirs::is_personal_project "${BATS_TEST_TMPDIR}/elsewhere/nope"
  assert_failure
}

@test "is_personal_project: relative path resolved via realpath -> true" {
  setup_personal_project
  mkdir --parents "${PERSONAL_PROJECTS_DIR}/repo"
  cd "${PERSONAL_PROJECTS_DIR}"
  run dirs::is_personal_project "repo"
  assert_success
}

@test "is_personal_project: dies with 0 args" {
  setup_personal_project
  run dirs::is_personal_project
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "is_personal_project: dies with 2 args" {
  setup_personal_project
  run dirs::is_personal_project 'a' 'b'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- dirs::assert_personal_project ----------

@test "assert_personal_project: PERSONAL_PROJECTS_DIR itself -> silent success" {
  setup_personal_project
  run dirs::assert_personal_project "${PERSONAL_PROJECTS_DIR}"
  assert_success
  assert_output ''
}

@test "assert_personal_project: subdir -> silent success" {
  setup_personal_project
  mkdir --parents "${PERSONAL_PROJECTS_DIR}/repo"
  run dirs::assert_personal_project "${PERSONAL_PROJECTS_DIR}/repo"
  assert_success
  assert_output ''
}

@test "assert_personal_project: outside -> dies" {
  setup_personal_project
  mkdir --parents "${BATS_TEST_TMPDIR}/work"
  run dirs::assert_personal_project "${BATS_TEST_TMPDIR}/work"
  assert_failure
  # shellcheck disable=SC2016 # intentional literal — asserting helper emits this exact substring
  assert_output --partial 'is not under ${PERSONAL_PROJECTS_DIR}'
}

@test "assert_personal_project: dies with 0 args" {
  setup_personal_project
  run dirs::assert_personal_project
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "assert_personal_project: dies with 2 args" {
  setup_personal_project
  run dirs::assert_personal_project 'a' 'b'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}
