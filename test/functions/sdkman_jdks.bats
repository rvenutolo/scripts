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
  source "${SCRIPTS_DIR}/functions/sdkman.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/sdkman_jdks.bash"
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
