#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/mvn.bash"
}

# ---------- list_pom_files ----------

@test "list_pom_files: returns sorted pom paths under given dir" {
  mkdir --parents "${BATS_TEST_TMPDIR}/a" "${BATS_TEST_TMPDIR}/b/c"
  touch "${BATS_TEST_TMPDIR}/pom.xml"
  touch "${BATS_TEST_TMPDIR}/a/pom.xml"
  touch "${BATS_TEST_TMPDIR}/b/c/pom.xml"
  run mvn::list_pom_files "${BATS_TEST_TMPDIR}"
  assert_success
  assert_line --index 0 "${BATS_TEST_TMPDIR}/a/pom.xml"
  assert_line --index 1 "${BATS_TEST_TMPDIR}/b/c/pom.xml"
  assert_line --index 2 "${BATS_TEST_TMPDIR}/pom.xml"
}

@test "list_pom_files: excludes target/ trees" {
  mkdir --parents "${BATS_TEST_TMPDIR}/target" "${BATS_TEST_TMPDIR}/sub/target"
  touch "${BATS_TEST_TMPDIR}/pom.xml"
  touch "${BATS_TEST_TMPDIR}/target/pom.xml"
  touch "${BATS_TEST_TMPDIR}/sub/target/pom.xml"
  run mvn::list_pom_files "${BATS_TEST_TMPDIR}"
  assert_success
  assert_line --index 0 "${BATS_TEST_TMPDIR}/pom.xml"
  refute_output --partial '/target/'
}

@test "list_pom_files: empty when no poms present" {
  mkdir --parents "${BATS_TEST_TMPDIR}/empty"
  run mvn::list_pom_files "${BATS_TEST_TMPDIR}/empty"
  assert_success
  assert_output ''
}

@test "list_pom_files: defaults to current directory when no arg given" {
  mkdir --parents "${BATS_TEST_TMPDIR}/cwd"
  touch "${BATS_TEST_TMPDIR}/cwd/pom.xml"
  cd "${BATS_TEST_TMPDIR}/cwd"
  run mvn::list_pom_files
  assert_success
  assert_output './pom.xml'
}

@test "list_pom_files: dies with too many args" {
  run mvn::list_pom_files a b
  assert_failure
  assert_output --partial 'Expected at most 1 argument'
}
