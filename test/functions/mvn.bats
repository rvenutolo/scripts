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

# ---------- prerelease_ignore_regex ----------

# Maven's Versions plugin applies each ignore regex with Java's Matcher.matches(), so the
# whole version must match; anchoring for PCRE grep reproduces that.
function prerelease_regex_matches() {
  local -r version="$1"
  local regex
  regex="$(mvn::prerelease_ignore_regex)"
  printf '%s\n' "${version}" | grep --perl-regexp --quiet "^(?:${regex})$"
}

@test "prerelease_ignore_regex: matches pre-release versions" {
  local -a prereleases=(
    '1.0-alpha' '1.0-alpha1' '1.0-alpha-1' '2.1.0-alpha1' '1.0.ALPHA2'
    '1.0-beta' '1.0-beta2' '4.0.0-beta-5' '1.0.Beta1'
    '2.2.0-M1' '5.0.0.M2' '1.0-m3' '1.0-milestone-1' '1.0.MILESTONE2'
    '1.0-RC' '1.0-RC1' '4.2.0-RC1' '1.0.RC1' '1.0-rc.2' '1.0-rc-3'
    '1.0-CR2' '1.0.CR1'
    '1.0-b1' '1.0-b-2' '1.0-a2'
    '2.0-M4-groovy-3.0' '1.0-beta-1-jre'
  )
  local version
  for version in "${prereleases[@]}"; do
    run prerelease_regex_matches "${version}"
    assert_success
  done
}

@test "prerelease_ignore_regex: does not match release versions" {
  local -a releases=(
    '1.0' '2.0.20' '4.1.2' '20040616'
    '33.8.0-jre' '33.0.0-android' '1.18.17-jdk5'
    '5.3.0.RELEASE' '5.6.15.Final' '1.0.GA'
    '1.1-groovy-2.4' '2.4-groovy-4.0'
    '1.0-b' '1.0-a' '1.0-amd64' '1.0-mysql' '1.0-crypto'
  )
  local version
  for version in "${releases[@]}"; do
    run prerelease_regex_matches "${version}"
    assert_failure 1
  done
}

@test "prerelease_ignore_regex: contains no comma" {
  # maven.version.ignore splits its value on commas into separate regexes.
  run mvn::prerelease_ignore_regex
  assert_success
  refute_output --partial ','
}

@test "prerelease_ignore_regex: prints a single line" {
  run mvn::prerelease_ignore_regex
  assert_success
  [[ "${#lines[@]}" -eq 1 ]]
}

@test "prerelease_ignore_regex: dies with any args" {
  run mvn::prerelease_ignore_regex a
  assert_failure
  assert_output --partial 'Expected no arguments'
}
