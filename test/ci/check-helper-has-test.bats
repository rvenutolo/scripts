bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-helper-has-test"
  FUNCS="${BATS_TEST_TMPDIR}/functions"
  TESTS="${BATS_TEST_TMPDIR}/test_functions"
  mkdir --parents "${FUNCS}" "${TESTS}"
  # The shipped list is empty today; set-but-empty clears it so an entry added
  # later cannot read as stale against these synthetic fixture dirs.
  export EXEMPT_OVERRIDE=''
}

# Write a library fixture defining each named function.
make_lib() {
  local -r topic="$1"
  shift
  local name
  printf '#!/usr/bin/env bash\n\n' > "${FUNCS}/${topic}.bash"
  for name in "$@"; do
    printf '# @description x\nfunction %s() {\n  true\n}\n\n' "${name}" >> "${FUNCS}/${topic}.bash"
  done
}

# Write a test fixture whose body is the given text.
make_test_file() {
  local -r file="$1"
  local -r body="$2"
  printf '@test "x" {\n  %s\n}\n' "${body}" > "${TESTS}/${file}"
}

# The lint derives its repo root via `git rev-parse --show-toplevel`, and
# common.bash leaves CWD outside any git repo, so cd into REPO_DIR first.
run_check() {
  cd "${REPO_DIR}" || return 1
  FUNCTIONS_DIR_OVERRIDE="${FUNCS}" TEST_FUNCTIONS_DIR_OVERRIDE="${TESTS}" \
    run --separate-stderr "${CHECK}" "$@"
}

@test "passes when every public helper is referenced" {
  make_lib 'demo' 'demo::one' 'demo::two'
  make_test_file 'demo.bats' 'run demo::one; run demo::two'
  run_check
  assert_success
}

@test "fails naming an unreferenced public helper" {
  make_lib 'demo' 'demo::one' 'demo::orphan'
  make_test_file 'demo.bats' 'run demo::one'
  run_check
  assert_failure 1
  assert_stderr --partial 'demo::orphan'
  assert_stderr --partial 'no test under test/functions references it'
}

@test "skips private ::_ helpers" {
  make_lib 'demo' 'demo::one' 'demo::_internal'
  make_test_file 'demo.bats' 'run demo::one'
  run_check
  assert_success
}

@test "a reference to a longer name does not cover a prefix" {
  make_lib 'demo' 'demo::is_empty'
  make_test_file 'demo.bats' 'run demo::is_empty_or_blank'
  run_check
  assert_failure 1
  assert_stderr --partial 'demo::is_empty '
}

@test "a reference in any test file counts" {
  make_lib 'demo' 'demo::one' 'demo::two'
  make_test_file 'demo.bats' 'run demo::one'
  make_test_file 'demo_extra.bats' 'run demo::two'
  run_check
  assert_success
}

@test "a reference at end of line counts" {
  make_lib 'demo' 'demo::one'
  printf '# covers demo::one\n' > "${TESTS}/demo.bats"
  run_check
  assert_success
}

@test "fails on a stale EXEMPT entry naming no helper" {
  make_lib 'demo' 'demo::one'
  make_test_file 'demo.bats' 'run demo::one'
  EXEMPT_OVERRIDE='demo::ghost' run_check
  assert_failure 1
  assert_stderr --partial 'stale'
}

@test "fails on a stale EXEMPT entry for a referenced helper" {
  make_lib 'demo' 'demo::one'
  make_test_file 'demo.bats' 'run demo::one'
  EXEMPT_OVERRIDE='demo::one' run_check
  assert_failure 1
  assert_stderr --partial 'stale'
}

@test "an exempt unreferenced helper passes" {
  make_lib 'demo' 'demo::one' 'demo::orphan'
  make_test_file 'demo.bats' 'run demo::one'
  EXEMPT_OVERRIDE='demo::orphan' run_check
  assert_success
}

@test "fails when the functions dir is missing" {
  rmdir "${FUNCS}"
  run_check
  assert_failure 1
}

@test "fails when the test dir is missing" {
  make_lib 'demo' 'demo::one'
  rmdir "${TESTS}"
  run_check
  assert_failure 1
}

@test "fails when no helpers are found" {
  make_lib 'demo'
  run_check
  assert_failure 1
}

@test "rejects arguments" {
  run_check oops
  assert_failure
  assert_stderr --partial 'Expected no arguments'
}

@test "--help exits 0" {
  run_check --help
  assert_success
}
