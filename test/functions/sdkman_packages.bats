#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/strings.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/text.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/symlinks.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/sdkman.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/sdkman_packages.bash"

  # shellcheck disable=SC2329 # invoked indirectly by sdkman_packages functions under test
  function sdk() {
    printf '%s\n' "$*" >> "${BATS_TEST_TMPDIR}/sdk.calls"
  }
  export -f sdk

  export SDKMAN_CANDIDATES_DIR="${BATS_TEST_TMPDIR}/candidates"
  mkdir --parents "${SDKMAN_CANDIDATES_DIR}"
}

# ---------- install_sdkman_package ----------

@test "install_sdkman_package: invokes sdk install <pkg>" {
  run sdkman_packages::install_sdkman_package gradle
  assert_success
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_output 'install gradle'
}

@test "install_sdkman_package: dies with wrong arg count" {
  run sdkman_packages::install_sdkman_package
  assert_failure
}

# ---------- uninstall_package_version ----------

@test "uninstall_package_version: invokes sdk uninstall <pkg> <ver>" {
  run sdkman_packages::uninstall_package_version gradle 8.5
  assert_success
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_output 'uninstall gradle 8.5'
}

@test "uninstall_package_version: dies with wrong arg count" {
  run sdkman_packages::uninstall_package_version gradle
  assert_failure
}

# ---------- get_installed_packages ----------

@test "get_installed_packages: returns sorted package names excluding java" {
  mkdir --parents "${SDKMAN_CANDIDATES_DIR}/gradle" \
    "${SDKMAN_CANDIDATES_DIR}/maven" \
    "${SDKMAN_CANDIDATES_DIR}/java"
  run sdkman_packages::get_installed_packages
  assert_success
  assert_line --index 0 'gradle'
  assert_line --index 1 'maven'
  refute_output --partial 'java'
}

@test "get_installed_packages: empty when only java present" {
  mkdir --parents "${SDKMAN_CANDIDATES_DIR}/java"
  run sdkman_packages::get_installed_packages
  assert_success
  assert_output ''
}

# ---------- get_installed_packages_versions ----------

@test "get_installed_packages_versions: returns sorted versions for given pkg (symlink excluded by -type d)" {
  # find -type d skips symlinks, so 'current' (a symlink) is not returned
  mkdir --parents "${SDKMAN_CANDIDATES_DIR}/gradle/8.5" \
    "${SDKMAN_CANDIDATES_DIR}/gradle/8.6"
  ln --symbolic '8.6' "${SDKMAN_CANDIDATES_DIR}/gradle/current"
  run sdkman_packages::get_installed_packages_versions gradle
  assert_success
  assert_line --index 0 '8.5'
  assert_line --index 1 '8.6'
  refute_output --partial 'current'
}

@test "get_installed_packages_versions: dies with wrong arg count" {
  run sdkman_packages::get_installed_packages_versions
  assert_failure
}

# ---------- get_current_package_version ----------

@test "get_current_package_version: returns target of current symlink" {
  mkdir --parents "${SDKMAN_CANDIDATES_DIR}/gradle/8.6"
  ln --symbolic '8.6' "${SDKMAN_CANDIDATES_DIR}/gradle/current"
  run sdkman_packages::get_current_package_version gradle
  assert_success
  assert_output '8.6'
}

@test "get_current_package_version: dies with wrong arg count" {
  run sdkman_packages::get_current_package_version
  assert_failure
}

# ---------- prune_sdkman_package ----------

@test "prune_sdkman_package: uninstalls all versions except current" {
  mkdir --parents "${SDKMAN_CANDIDATES_DIR}/gradle/8.4" \
    "${SDKMAN_CANDIDATES_DIR}/gradle/8.5" \
    "${SDKMAN_CANDIDATES_DIR}/gradle/8.6"
  ln --symbolic '8.6' "${SDKMAN_CANDIDATES_DIR}/gradle/current"
  run sdkman_packages::prune_sdkman_package gradle
  assert_success
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  # find -type d returns 8.4, 8.5, 8.6 (skips the 'current' symlink).
  # Current version is 8.6, so 8.4 and 8.5 are uninstalled; 8.6 is kept.
  assert_line --index 0 'uninstall gradle 8.4'
  assert_line --index 1 'uninstall gradle 8.5'
  refute_output --partial 'uninstall gradle 8.6'
  refute_output --partial 'uninstall gradle current'
}

# ---------- install_sdkman_packages ----------

@test "install_sdkman_packages: iterates packages::get_sdkman output" {
  function packages::get_sdkman() { printf 'gradle\nmaven\n'; }
  export -f packages::get_sdkman
  run sdkman_packages::install_sdkman_packages
  assert_success
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_line --index 0 'install gradle'
  assert_line --index 1 'install maven'
}

# ---------- prune_sdkman_packages ----------

@test "prune_sdkman_packages: iterates installed packages and prunes each" {
  mkdir --parents "${SDKMAN_CANDIDATES_DIR}/gradle/8.4" \
    "${SDKMAN_CANDIDATES_DIR}/gradle/8.5"
  ln --symbolic '8.5' "${SDKMAN_CANDIDATES_DIR}/gradle/current"
  mkdir --parents "${SDKMAN_CANDIDATES_DIR}/maven/3.9.0" \
    "${SDKMAN_CANDIDATES_DIR}/maven/3.9.5"
  ln --symbolic '3.9.5' "${SDKMAN_CANDIDATES_DIR}/maven/current"
  run sdkman_packages::prune_sdkman_packages
  assert_success
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_output --partial 'uninstall gradle 8.4'
  assert_output --partial 'uninstall maven 3.9.0'
}
