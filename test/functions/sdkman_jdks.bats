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
  source "${SCRIPTS_DIR}/functions/grep.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/misc.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/dirs.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/prompt.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/files.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/symlinks.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/sdkman.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/sdkman_jdks.bash"
  export SDKMAN_CANDIDATES_DIR="${BATS_TEST_TMPDIR}/candidates"
  mkdir --parents "${SDKMAN_CANDIDATES_DIR}/java"
}

# ---------- get_jdk_major_version ----------

@test "get_jdk_major_version: extracts from artifact id" {
  run sdkman_jdks::get_jdk_major_version '21.0.3-tem'
  assert_success
  assert_output '21'
}

@test "get_jdk_major_version: extracts from bare major" {
  run sdkman_jdks::get_jdk_major_version '8'
  assert_success
  assert_output '8'
}

@test "get_jdk_major_version: extracts from multi-digit major" {
  run sdkman_jdks::get_jdk_major_version '17.0.10-tem'
  assert_success
  assert_output '17'
}

@test "get_jdk_major_version: dies on non-numeric input" {
  run sdkman_jdks::get_jdk_major_version 'bogus'
  assert_failure
  assert_output --partial 'Unexpected version'
}

@test "get_jdk_major_version: dies with wrong arg count" {
  run sdkman_jdks::get_jdk_major_version
  assert_failure
}

# ---------- filter_for_installed ----------

@test "filter_for_installed: keeps only y rows" {
  run bash -c "
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/sdkman_jdks.bash'
    printf '21;21.0.3;21.0.3-tem;y\n17;17.0.10;17.0.10-tem;n\n' | sdkman_jdks::filter_for_installed
  "
  assert_success
  assert_output '21;21.0.3;21.0.3-tem;y'
}

@test "filter_for_installed: empty stdin yields empty output" {
  # BATS run connects stdin to a pipe (not a tty), so check_for_stdin passes;
  # with no matching rows the function succeeds with empty output.
  run sdkman_jdks::filter_for_installed < /dev/null
  assert_success
  assert_output ''
}

# ---------- filter_for_major_version ----------

@test "filter_for_major_version: keeps only matching major" {
  run bash -c "
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/sdkman_jdks.bash'
    printf '21;21.0.3;21.0.3-tem;y\n17;17.0.10;17.0.10-tem;y\n' | sdkman_jdks::filter_for_major_version 21
  "
  assert_success
  assert_output '21;21.0.3;21.0.3-tem;y'
}

@test "filter_for_major_version: dies with wrong arg count" {
  run bash -c "
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/sdkman_jdks.bash'
    printf 'x\n' | sdkman_jdks::filter_for_major_version
  "
  assert_failure
}

# ---------- filter_for_latest_per_major_version ----------

@test "filter_for_latest_per_major_version: keeps first row per major" {
  run bash -c "
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/sdkman_jdks.bash'
    printf '21;21.0.5;21.0.5-tem;y\n21;21.0.3;21.0.3-tem;y\n17;17.0.10;17.0.10-tem;y\n' | sdkman_jdks::filter_for_latest_per_major_version
  "
  assert_success
  assert_line --index 0 '21;21.0.5;21.0.5-tem;y'
  assert_line --index 1 '17;17.0.10;17.0.10-tem;y'
}

# ---------- get_formatted_tem_jdk_*_field ----------

@test "get_formatted_tem_jdk_major_version_field: extracts col 1" {
  run bash -c "
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/sdkman_jdks.bash'
    printf '21;21.0.3;21.0.3-tem;y\n' | sdkman_jdks::get_formatted_tem_jdk_major_version_field
  "
  assert_success
  assert_output '21'
}

@test "get_formatted_tem_jdk_version_field: extracts col 2" {
  run bash -c "
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/sdkman_jdks.bash'
    printf '21;21.0.3;21.0.3-tem;y\n' | sdkman_jdks::get_formatted_tem_jdk_version_field
  "
  assert_success
  assert_output '21.0.3'
}

@test "get_formatted_tem_jdk_artifact_id_field: extracts col 3" {
  run bash -c "
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/sdkman_jdks.bash'
    printf '21;21.0.3;21.0.3-tem;y\n' | sdkman_jdks::get_formatted_tem_jdk_artifact_id_field
  "
  assert_success
  assert_output '21.0.3-tem'
}

@test "all field extractors: empty stdin yields empty output" {
  # BATS run connects stdin to a pipe (not a tty), so check_for_stdin passes;
  # with empty input the cut commands succeed with empty output.
  for fn in get_formatted_tem_jdk_major_version_field get_formatted_tem_jdk_version_field get_formatted_tem_jdk_artifact_id_field; do
    run "sdkman_jdks::${fn}" < /dev/null
    assert_success
    assert_output ''
  done
}

# ---------- helpers for wrapper tests ----------

# Canned formatted JDK rows for stubbing get_formatted_all_tem_jdks.
readonly CANNED_JDKS='21;21.0.5;21.0.5-tem;y
21;21.0.3;21.0.3-tem;y
17;17.0.10;17.0.10-tem;y
17;17.0.8;17.0.8-tem;n
11;11.0.22;11.0.22-tem;n'

stub_jdks_and_sdk() {
  function sdkman_jdks::get_formatted_all_tem_jdks() { printf '%s\n' "${CANNED_JDKS}"; }
  function sdk() { printf '%s\n' "$*" >> "${BATS_TEST_TMPDIR}/sdk.calls"; }
  export -f sdkman_jdks::get_formatted_all_tem_jdks sdk
}

# SDKMAN_CANDIDATES_DIR is exported once in setup(); this only creates the symlink.
fixture_default_symlink() {
  # $1 = artifact id, e.g. 17.0.19-tem
  mkdir --parents "${SDKMAN_CANDIDATES_DIR}/java/$1"
  ln --symbolic "${SDKMAN_CANDIDATES_DIR}/java/$1" "${SDKMAN_CANDIDATES_DIR}/java/current"
}

# ---------- get_formatted_all_tem_jdks (parser test) ----------

@test "get_formatted_all_tem_jdks: parses pipe-delimited sdk list java output" {
  # shellcheck disable=SC2329 # invoked indirectly via export -f by sdkman functions under test
  function sdk() {
    cat << 'EOF'
================================================================================
Available Java Versions for Linux 64bit
================================================================================
 Vendor        | Use | Version      | Dist    | Status     | Identifier
--------------------------------------------------------------------------------
 Temurin       |     | 21.0.5       | tem     |            | 21.0.5-tem
 Temurin       | >>> | 21.0.3       | tem     | installed  | 21.0.3-tem
 Temurin       |     | 17.0.10      | tem     | installed  | 17.0.10-tem
 Eclipse       |     | 21.0.5       | sapmchn |            | 21.0.5-sapmchn
EOF
  }
  export -f sdk
  run sdkman_jdks::get_formatted_all_tem_jdks
  assert_success
  assert_line --index 0 '21;21.0.5;21.0.5-tem;n'
  assert_line --index 1 '21;21.0.3;21.0.3-tem;y'
  assert_line --index 2 '17;17.0.10;17.0.10-tem;y'
  refute_output --partial 'sapmchn'
}

# ---------- install_jdk / uninstall_jdk / set_default_jdk_by_id ----------

@test "install_jdk: invokes sdk install java <id>" {
  stub_jdks_and_sdk
  run sdkman_jdks::install_jdk '21.0.5-tem'
  assert_success
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_output 'install java 21.0.5-tem'
}

@test "uninstall_jdk: invokes sdk uninstall java <id>" {
  stub_jdks_and_sdk
  run sdkman_jdks::uninstall_jdk '21.0.3-tem'
  assert_success
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_output 'uninstall java 21.0.3-tem'
}

@test "set_default_jdk_by_id: invokes sdk default java <id>" {
  stub_jdks_and_sdk
  run sdkman_jdks::set_default_jdk_by_id '21.0.5-tem'
  assert_success
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_output 'default java 21.0.5-tem'
}

# ---------- latest_available_* ----------

@test "get_formatted_latest_available_tem_jdk_major_versions: returns latest per major" {
  stub_jdks_and_sdk
  run sdkman_jdks::get_formatted_latest_available_tem_jdk_major_versions
  assert_success
  assert_line --index 0 '21;21.0.5;21.0.5-tem;y'
  assert_line --index 1 '17;17.0.10;17.0.10-tem;y'
  assert_line --index 2 '11;11.0.22;11.0.22-tem;n'
}

@test "get_formatted_latest_available_tem_jdk_for_major_version: returns latest for given major" {
  stub_jdks_and_sdk
  run sdkman_jdks::get_formatted_latest_available_tem_jdk_for_major_version 17
  assert_success
  assert_output '17;17.0.10;17.0.10-tem;y'
}

@test "get_formatted_latest_available_tem_jdk_for_major_version: dies for unavailable major" {
  stub_jdks_and_sdk
  run sdkman_jdks::get_formatted_latest_available_tem_jdk_for_major_version 99
  assert_failure
  assert_output --partial 'Java version 99 is not available'
}

# ---------- available major versions ----------

@test "get_available_tem_jdk_major_versions: numerically sorted unique majors" {
  stub_jdks_and_sdk
  run sdkman_jdks::get_available_tem_jdk_major_versions
  assert_success
  assert_line --index 0 '11'
  assert_line --index 1 '17'
  assert_line --index 2 '21'
}

@test "get_latest_available_tem_jdk_major_version: returns highest major" {
  stub_jdks_and_sdk
  run sdkman_jdks::get_latest_available_tem_jdk_major_version
  assert_success
  assert_output '21'
}

@test "check_available_tem_jdk_major_version: succeeds for available major" {
  stub_jdks_and_sdk
  run sdkman_jdks::check_available_tem_jdk_major_version 21
  assert_success
}

@test "check_available_tem_jdk_major_version: dies for unavailable major" {
  stub_jdks_and_sdk
  run sdkman_jdks::check_available_tem_jdk_major_version 99
  assert_failure
  assert_output --partial 'Java version 99 is not available'
}

# ---------- installed-jdk family ----------

@test "get_formatted_installed_tem_jdks: returns only y rows" {
  stub_jdks_and_sdk
  run sdkman_jdks::get_formatted_installed_tem_jdks
  assert_success
  assert_line --index 0 '21;21.0.5;21.0.5-tem;y'
  assert_line --index 1 '21;21.0.3;21.0.3-tem;y'
  assert_line --index 2 '17;17.0.10;17.0.10-tem;y'
  refute_output --partial '11.0.22'
}

@test "get_formatted_installed_tem_jdks_for_major_version: filters installed by major" {
  stub_jdks_and_sdk
  run sdkman_jdks::get_formatted_installed_tem_jdks_for_major_version 21
  assert_success
  assert_line --index 0 '21;21.0.5;21.0.5-tem;y'
  assert_line --index 1 '21;21.0.3;21.0.3-tem;y'
}

@test "get_formatted_latest_installed_tem_jdk_major_versions: latest installed per major" {
  stub_jdks_and_sdk
  run sdkman_jdks::get_formatted_latest_installed_tem_jdk_major_versions
  assert_success
  assert_line --index 0 '21;21.0.5;21.0.5-tem;y'
  assert_line --index 1 '17;17.0.10;17.0.10-tem;y'
}

@test "get_formatted_latest_installed_tem_jdk_for_major_version: returns latest installed for major" {
  stub_jdks_and_sdk
  run sdkman_jdks::get_formatted_latest_installed_tem_jdk_for_major_version 21
  assert_success
  assert_output '21;21.0.5;21.0.5-tem;y'
}

@test "get_formatted_latest_installed_tem_jdk_for_major_version: dies for non-installed major" {
  stub_jdks_and_sdk
  run sdkman_jdks::get_formatted_latest_installed_tem_jdk_for_major_version 11
  assert_failure
  assert_output --partial 'Java version 11 is not installed'
}

@test "get_installed_tem_jdk_major_versions: numerically sorted unique installed majors" {
  stub_jdks_and_sdk
  run sdkman_jdks::get_installed_tem_jdk_major_versions
  assert_success
  assert_line --index 0 '17'
  assert_line --index 1 '21'
}

@test "get_latest_installed_tem_jdk_major_version: returns highest installed major" {
  stub_jdks_and_sdk
  run sdkman_jdks::get_latest_installed_tem_jdk_major_version
  assert_success
  assert_output '21'
}

@test "check_installed_tem_jdk_major_version: succeeds for installed" {
  stub_jdks_and_sdk
  run sdkman_jdks::check_installed_tem_jdk_major_version 21
  assert_success
}

@test "check_installed_tem_jdk_major_version: dies for non-installed" {
  stub_jdks_and_sdk
  run sdkman_jdks::check_installed_tem_jdk_major_version 11
  assert_failure
}

@test "is_tem_jdk_artifact_installed: true for installed artifact" {
  stub_jdks_and_sdk
  run sdkman_jdks::is_tem_jdk_artifact_installed '21.0.3-tem'
  assert_success
}

@test "is_tem_jdk_artifact_installed: false for non-installed artifact" {
  stub_jdks_and_sdk
  run sdkman_jdks::is_tem_jdk_artifact_installed '17.0.8-tem'
  assert_failure
}

@test "get_latest_installed_tem_jdk_artifact_id_for_major_version: returns artifact id" {
  stub_jdks_and_sdk
  run sdkman_jdks::get_latest_installed_tem_jdk_artifact_id_for_major_version 21
  assert_success
  assert_output '21.0.5-tem'
}

# ---------- installing / setting default / pruning ----------

@test "install_latest_tem_jdk: installs latest available for major" {
  stub_jdks_and_sdk
  run sdkman_jdks::install_latest_tem_jdk 21
  assert_success
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_output 'install java 21.0.5-tem'
}

@test "install_latest_tem_jdks: installs latest for every major" {
  stub_jdks_and_sdk
  run sdkman_jdks::install_latest_tem_jdks
  assert_success
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_line --index 0 'install java 11.0.22-tem'
  assert_line --index 1 'install java 17.0.10-tem'
  assert_line --index 2 'install java 21.0.5-tem'
}

@test "set_default_sdk_to_latest_installed_for_major_version: sets default to latest installed" {
  stub_jdks_and_sdk
  run sdkman_jdks::set_default_sdk_to_latest_installed_for_major_version 21
  assert_success
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_output 'default java 21.0.5-tem'
}

# ---------- has_default_jdk ----------

@test "has_default_jdk: true when current symlink exists" {
  fixture_default_symlink '17.0.19-tem'
  run sdkman_jdks::has_default_jdk
  assert_success
}

@test "has_default_jdk: false when no current symlink" {
  # setup() creates candidates/java with no current symlink
  run sdkman_jdks::has_default_jdk
  assert_failure
}

@test "has_default_jdk: dies with wrong arg count" {
  run sdkman_jdks::has_default_jdk x
  assert_failure
}

# ---------- get_current_default_jdk_major_version ----------

@test "get_current_default_jdk_major_version: extracts major from current symlink" {
  fixture_default_symlink '17.0.19-tem'
  run sdkman_jdks::get_current_default_jdk_major_version
  assert_success
  assert_output '17'
}

@test "get_current_default_jdk_major_version: multi-digit major" {
  fixture_default_symlink '21.0.5-tem'
  run sdkman_jdks::get_current_default_jdk_major_version
  assert_success
  assert_output '21'
}

@test "get_current_default_jdk_major_version: dies when no symlink" {
  # setup() creates candidates/java with no current symlink
  run sdkman_jdks::get_current_default_jdk_major_version
  assert_failure
}

@test "get_current_default_jdk_major_version: dies with wrong arg count" {
  run sdkman_jdks::get_current_default_jdk_major_version x
  assert_failure
}

# ---------- set_default_jdk_to_latest_patch_of_current_major ----------

@test "set_default_jdk_to_latest_patch_of_current_major: uses current major when a default is set" {
  stub_jdks_and_sdk
  fixture_default_symlink '17.0.19-tem'
  run sdkman_jdks::set_default_jdk_to_latest_patch_of_current_major
  assert_success
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_output 'default java 17.0.10-tem'
}

@test "set_default_jdk_to_latest_patch_of_current_major: falls back to highest installed major when no default set" {
  stub_jdks_and_sdk
  # setup() creates candidates/java with no current symlink
  run sdkman_jdks::set_default_jdk_to_latest_patch_of_current_major
  assert_success
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_output 'default java 21.0.5-tem'
}

@test "prune_tem_jdks_for_major_version: uninstalls all installed for major except latest available" {
  stub_jdks_and_sdk
  run sdkman_jdks::prune_tem_jdks_for_major_version 21
  assert_success
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_output 'uninstall java 21.0.3-tem'
}

@test "prune_tem_jdks: prunes across every installed major" {
  stub_jdks_and_sdk
  run sdkman_jdks::prune_tem_jdks
  assert_success
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_output --partial 'uninstall java 21.0.3-tem'
}
