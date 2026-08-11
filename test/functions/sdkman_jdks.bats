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
  # The catalog memo is keyed on $$, which is identical for every test in this file, so isolation
  # comes from XDG_RUNTIME_DIR pointing at the per-test tmpdir.
  export XDG_RUNTIME_DIR="${BATS_TEST_TMPDIR}"
}

# Serve a canned `sdk list java` payload and record every sdk invocation, so tests can assert how
# many network round-trips a code path would make.
stub_sdk_catalog() {
  # shellcheck disable=SC2329 # invoked indirectly via export -f by sdkman functions under test
  function sdk() {
    printf '%s\n' "$*" >> "${BATS_TEST_TMPDIR}/sdk.calls"
    if [[ "$1" == 'list' ]]; then
      cat << 'EOF'
 Vendor        | Use | Version      | Dist    | Status     | Identifier
--------------------------------------------------------------------------------
 Temurin       |     | 21.0.5       | tem     |            | 21.0.5-tem
 Temurin       | >>> | 21.0.3       | tem     | installed  | 21.0.3-tem
 Temurin       |     | 17.0.10      | tem     | installed  | 17.0.10-tem
 Eclipse       |     | 21.0.5       | sapmchn |            | 21.0.5-sapmchn
EOF
    fi
  }
  export -f sdk
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

@test "filter_for_installed: dies with args" {
  run sdkman_jdks::filter_for_installed 'extra' < /dev/null
  assert_failure
  assert_output --partial 'Expected no arguments'
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

@test "filter_for_latest_per_major_version: dies with args" {
  run sdkman_jdks::filter_for_latest_per_major_version 'extra' < /dev/null
  assert_failure
  assert_output --partial 'Expected no arguments'
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

@test "get_formatted_tem_jdk_major_version_field: dies with args" {
  run sdkman_jdks::get_formatted_tem_jdk_major_version_field 'extra' < /dev/null
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "get_formatted_tem_jdk_version_field: dies with args" {
  run sdkman_jdks::get_formatted_tem_jdk_version_field 'extra' < /dev/null
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "get_formatted_tem_jdk_artifact_id_field: dies with args" {
  run sdkman_jdks::get_formatted_tem_jdk_artifact_id_field 'extra' < /dev/null
  assert_failure
  assert_output --partial 'Expected no arguments'
}

# ---------- helpers for wrapper tests ----------

# Canned formatted JDK rows for stubbing get_formatted_all_tem_jdks.
readonly CANNED_JDKS='21;21.0.5;21.0.5-tem;y
21;21.0.3;21.0.3-tem;y
17;17.0.10;17.0.10-tem;y
17;17.0.8;17.0.8-tem;n
11;11.0.22;11.0.22-tem;n'

# Create candidate dirs for the given artifact ids. The installed-* helpers read the SDKMAN
# candidates dir rather than `sdk list java`, so installed state must exist on disk.
fixture_installed_jdks() {
  local artifact_id
  for artifact_id in "$@"; do
    mkdir --parents "${SDKMAN_CANDIDATES_DIR}/java/${artifact_id}"
  done
}

stub_jdks_and_sdk() {
  function sdkman_jdks::get_formatted_all_tem_jdks() { printf '%s\n' "${CANNED_JDKS}"; }
  function sdk() { printf '%s\n' "$*" >> "${BATS_TEST_TMPDIR}/sdk.calls"; }
  export -f sdkman_jdks::get_formatted_all_tem_jdks sdk
  # Mirror the 'y' rows of CANNED_JDKS on disk so the two sources of truth agree.
  fixture_installed_jdks '21.0.5-tem' '21.0.3-tem' '17.0.10-tem'
}

# SDKMAN_CANDIDATES_DIR is exported once in setup(); this only creates the symlink.
fixture_default_symlink() {
  # $1 = artifact id, e.g. 17.0.19-tem
  mkdir --parents "${SDKMAN_CANDIDATES_DIR}/java/$1"
  ln --symbolic "${SDKMAN_CANDIDATES_DIR}/java/$1" "${SDKMAN_CANDIDATES_DIR}/java/current"
}

# ---------- fetch_tem_jdk_catalog (parser test) ----------

@test "fetch_tem_jdk_catalog: parses pipe-delimited sdk list java output" {
  stub_sdk_catalog
  run sdkman_jdks::fetch_tem_jdk_catalog
  assert_success
  assert_line --index 0 '21;21.0.5;21.0.5-tem'
  assert_line --index 1 '21;21.0.3;21.0.3-tem'
  assert_line --index 2 '17;17.0.10;17.0.10-tem'
  refute_output --partial 'sapmchn'
}

@test "fetch_tem_jdk_catalog: discards the sdk-reported installed status" {
  # Installed state is owned by the candidates dir, so no 'y'/'n' column here even though the
  # canned payload marks 21.0.3 and 17.0.10 as installed.
  stub_sdk_catalog
  run sdkman_jdks::fetch_tem_jdk_catalog
  assert_success
  refute_output --partial ';y'
  refute_output --partial ';n'
}

@test "fetch_tem_jdk_catalog: dies with args" {
  run sdkman_jdks::fetch_tem_jdk_catalog extra
  assert_failure
}

# ---------- catalog_cache_file ----------

@test "catalog_cache_file: lives under XDG_RUNTIME_DIR and is keyed on the pid" {
  run sdkman_jdks::catalog_cache_file
  assert_success
  assert_output "${XDG_RUNTIME_DIR}/sdkman-tem-jdk-catalog.$$"
}

@test "catalog_cache_file: dies with args" {
  run sdkman_jdks::catalog_cache_file extra
  assert_failure
}

# ---------- get_tem_jdk_catalog (memoization) ----------

@test "get_tem_jdk_catalog: returns the catalog" {
  stub_sdk_catalog
  run sdkman_jdks::get_tem_jdk_catalog
  assert_success
  assert_line --index 0 '21;21.0.5;21.0.5-tem'
  assert_line --index 2 '17;17.0.10;17.0.10-tem'
}

@test "get_tem_jdk_catalog: fetches once even when called from inside pipelines" {
  # A pipeline segment runs in a subshell, so a variable-based memo would be discarded and every
  # one of these calls would hit the network. This is the regression this design exists to prevent.
  stub_sdk_catalog
  sdkman_jdks::get_tem_jdk_catalog | cat > /dev/null
  sdkman_jdks::get_tem_jdk_catalog | cat > /dev/null
  sdkman_jdks::get_tem_jdk_catalog > /dev/null
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_output 'list java'
}

@test "get_tem_jdk_catalog: memoized output matches the freshly fetched output" {
  stub_sdk_catalog
  sdkman_jdks::get_tem_jdk_catalog > "${BATS_TEST_TMPDIR}/first"
  sdkman_jdks::get_tem_jdk_catalog > "${BATS_TEST_TMPDIR}/second"
  run diff "${BATS_TEST_TMPDIR}/first" "${BATS_TEST_TMPDIR}/second"
  assert_success
}

@test "get_tem_jdk_catalog: refetches when the memo predates this process" {
  # Simulates a recycled pid finding a dead namesake's memo still sitting in XDG_RUNTIME_DIR.
  stub_sdk_catalog
  sdkman_jdks::get_tem_jdk_catalog > /dev/null
  touch --date='2000-01-01' "$(sdkman_jdks::catalog_cache_file)"
  sdkman_jdks::get_tem_jdk_catalog > /dev/null
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_line --index 0 'list java'
  assert_line --index 1 'list java'
  assert_equal "${#lines[@]}" 2
}

@test "get_tem_jdk_catalog: reports failure when the fetch fails" {
  # Every script that sources this library runs under `set -Eeuo pipefail`; bats does not. Without
  # pipefail a failing `sdk` inside `sdk list java | awk ...` is masked by awk's success, so the
  # test would not model production. bats isolates each @test in its own subshell, so this cannot
  # leak into other tests.
  set -o pipefail
  # shellcheck disable=SC2329 # invoked indirectly via export -f by the function under test
  function sdk() { return 1; }
  export -f sdk
  run sdkman_jdks::get_tem_jdk_catalog
  assert_failure
}

@test "get_tem_jdk_catalog: a failed fetch is never cached" {
  # Guarding this with errexit alone is not enough: callers reach get_tem_jdk_catalog from `if`
  # and `||` contexts (check_available_tem_jdk_major_version does), and errexit is disabled inside
  # a function invoked that way — so a partial response would be promoted to the memo and served
  # for the rest of the process. Exercise exactly that shape, under production's pipefail.
  set -o pipefail
  # shellcheck disable=SC2329 # invoked indirectly via export -f by the function under test
  function sdk() {
    printf '%s\n' "$*" >> "${BATS_TEST_TMPDIR}/sdk.calls"
    printf ' Temurin       |     | 21.0.5       | tem     |            | 21.0.5-tem\n'
    return 1
  }
  export -f sdk
  if sdkman_jdks::get_tem_jdk_catalog > /dev/null 2>&1; then :; fi
  refute [ -e "$(sdkman_jdks::catalog_cache_file)" ]

  # A later call must retry rather than serve the truncated response.
  stub_sdk_catalog
  run sdkman_jdks::get_tem_jdk_catalog
  assert_success
  assert_line --index 0 '21;21.0.5;21.0.5-tem'
  assert_line --index 2 '17;17.0.10;17.0.10-tem'
}

@test "get_tem_jdk_catalog: dies with args" {
  run sdkman_jdks::get_tem_jdk_catalog extra
  assert_failure
}

# ---------- get_formatted_all_tem_jdks (installed annotation) ----------

@test "get_formatted_all_tem_jdks: annotates installed status from the candidates dir" {
  stub_sdk_catalog
  fixture_installed_jdks '21.0.3-tem' '17.0.10-tem'
  run sdkman_jdks::get_formatted_all_tem_jdks
  assert_success
  assert_line --index 0 '21;21.0.5;21.0.5-tem;n'
  assert_line --index 1 '21;21.0.3;21.0.3-tem;y'
  assert_line --index 2 '17;17.0.10;17.0.10-tem;y'
  refute_output --partial 'sapmchn'
}

@test "get_formatted_all_tem_jdks: all n when nothing is installed" {
  stub_sdk_catalog
  run sdkman_jdks::get_formatted_all_tem_jdks
  assert_success
  assert_line --index 0 '21;21.0.5;21.0.5-tem;n'
  assert_line --index 1 '21;21.0.3;21.0.3-tem;n'
  assert_line --index 2 '17;17.0.10;17.0.10-tem;n'
}

@test "get_formatted_all_tem_jdks: installed column tracks installs made after the memo was filled" {
  # The memo holds only the catalog, never the installed column, so an install performed mid-run
  # is reflected immediately without any cache invalidation.
  stub_sdk_catalog
  run sdkman_jdks::get_formatted_all_tem_jdks
  assert_success
  assert_line --index 0 '21;21.0.5;21.0.5-tem;n'
  fixture_installed_jdks '21.0.5-tem'
  run sdkman_jdks::get_formatted_all_tem_jdks
  assert_success
  assert_line --index 0 '21;21.0.5;21.0.5-tem;y'
  # ...and still only one round-trip across both calls.
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_output 'list java'
}

@test "get_formatted_all_tem_jdks: empty catalog yields empty output" {
  # shellcheck disable=SC2329 # invoked indirectly via export -f by the function under test
  function sdk() { :; }
  export -f sdk
  run sdkman_jdks::get_formatted_all_tem_jdks
  assert_success
  assert_output ''
}

@test "get_formatted_all_tem_jdks: dies with args" {
  run sdkman_jdks::get_formatted_all_tem_jdks extra
  assert_failure
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

@test "install_jdk: dies with 0 args" {
  run sdkman_jdks::install_jdk < /dev/null
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "uninstall_jdk: dies with 0 args" {
  run sdkman_jdks::uninstall_jdk < /dev/null
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "set_default_jdk_by_id: dies with 0 args" {
  run sdkman_jdks::set_default_jdk_by_id < /dev/null
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
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

@test "get_formatted_latest_available_tem_jdk_major_versions: dies with args" {
  run sdkman_jdks::get_formatted_latest_available_tem_jdk_major_versions 'extra' < /dev/null
  assert_failure
  assert_output --partial 'Expected no arguments'
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

@test "get_formatted_latest_available_tem_jdk_for_major_version: dies with 0 args" {
  run sdkman_jdks::get_formatted_latest_available_tem_jdk_for_major_version < /dev/null
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
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

@test "get_available_tem_jdk_major_versions: dies with args" {
  run sdkman_jdks::get_available_tem_jdk_major_versions 'extra' < /dev/null
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "get_latest_available_tem_jdk_major_version: returns highest major" {
  stub_jdks_and_sdk
  run sdkman_jdks::get_latest_available_tem_jdk_major_version
  assert_success
  assert_output '21'
}

@test "get_latest_available_tem_jdk_major_version: dies with args" {
  run sdkman_jdks::get_latest_available_tem_jdk_major_version 'extra' < /dev/null
  assert_failure
  assert_output --partial 'Expected no arguments'
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

@test "check_available_tem_jdk_major_version: dies with 0 args" {
  run sdkman_jdks::check_available_tem_jdk_major_version < /dev/null
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- get_formatted_installed_tem_jdks (candidates-dir source) ----------

@test "get_formatted_installed_tem_jdks: formats every candidate dir, newest first" {
  fixture_installed_jdks '8.0.492-tem' '11.0.32-tem' '21.0.9-tem' '21.0.12-tem'
  run sdkman_jdks::get_formatted_installed_tem_jdks
  assert_success
  # Ordering must be version-aware, not lexicographic: 21 before 11 before 8 across majors,
  # and 21.0.12 before 21.0.9 within a major.
  assert_line --index 0 '21;21.0.12;21.0.12-tem;y'
  assert_line --index 1 '21;21.0.9;21.0.9-tem;y'
  assert_line --index 2 '11;11.0.32;11.0.32-tem;y'
  assert_line --index 3 '8;8.0.492;8.0.492-tem;y'
}

@test "get_formatted_installed_tem_jdks: single installed jdk" {
  fixture_installed_jdks '21.0.5-tem'
  run sdkman_jdks::get_formatted_installed_tem_jdks
  assert_success
  assert_output '21;21.0.5;21.0.5-tem;y'
}

@test "get_formatted_installed_tem_jdks: ignores non-temurin candidates" {
  fixture_installed_jdks '21.0.5-tem' '21.0.5-oracle' '21.0.5-graalce' '21.0.5-amzn'
  run sdkman_jdks::get_formatted_installed_tem_jdks
  assert_success
  assert_output '21;21.0.5;21.0.5-tem;y'
}

@test "get_formatted_installed_tem_jdks: ignores the current symlink" {
  fixture_default_symlink '21.0.5-tem'
  run sdkman_jdks::get_formatted_installed_tem_jdks
  assert_success
  assert_output '21;21.0.5;21.0.5-tem;y'
  refute_output --partial 'current'
}

@test "get_formatted_installed_tem_jdks: ignores plain files named like an artifact" {
  fixture_installed_jdks '21.0.5-tem'
  touch "${SDKMAN_CANDIDATES_DIR}/java/17.0.10-tem"
  run sdkman_jdks::get_formatted_installed_tem_jdks
  assert_success
  assert_output '21;21.0.5;21.0.5-tem;y'
}

@test "get_formatted_installed_tem_jdks: empty when no candidates installed" {
  # setup() creates an empty candidates/java dir
  run sdkman_jdks::get_formatted_installed_tem_jdks
  assert_success
  assert_output ''
}

@test "get_formatted_installed_tem_jdks: empty when candidates dir does not exist" {
  rm --recursive --force -- "${SDKMAN_CANDIDATES_DIR}/java"
  run sdkman_jdks::get_formatted_installed_tem_jdks
  assert_success
  assert_output ''
}

@test "get_formatted_installed_tem_jdks: makes no sdk call" {
  # The whole point of reading the candidates dir is avoiding the network round-trip that
  # `sdk list java` performs on every invocation.
  # shellcheck disable=SC2329 # deliberately never invoked; the test asserts it is not called
  function sdk() { printf '%s\n' "$*" >> "${BATS_TEST_TMPDIR}/sdk.calls"; }
  export -f sdk
  fixture_installed_jdks '21.0.5-tem'
  run sdkman_jdks::get_formatted_installed_tem_jdks
  assert_success
  assert_output '21;21.0.5;21.0.5-tem;y'
  refute [ -e "${BATS_TEST_TMPDIR}/sdk.calls" ]
}

@test "get_formatted_installed_tem_jdks: dies with args" {
  run sdkman_jdks::get_formatted_installed_tem_jdks extra
  assert_failure
}

# ---------- installed-jdk family ----------

@test "get_formatted_installed_tem_jdks: reflects the canned installed set" {
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

@test "get_formatted_installed_tem_jdks_for_major_version: dies with 0 args" {
  run sdkman_jdks::get_formatted_installed_tem_jdks_for_major_version < /dev/null
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "get_formatted_latest_installed_tem_jdk_major_versions: latest installed per major" {
  stub_jdks_and_sdk
  run sdkman_jdks::get_formatted_latest_installed_tem_jdk_major_versions
  assert_success
  assert_line --index 0 '21;21.0.5;21.0.5-tem;y'
  assert_line --index 1 '17;17.0.10;17.0.10-tem;y'
}

@test "get_formatted_latest_installed_tem_jdk_major_versions: dies with args" {
  run sdkman_jdks::get_formatted_latest_installed_tem_jdk_major_versions 'extra' < /dev/null
  assert_failure
  assert_output --partial 'Expected no arguments'
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

@test "get_formatted_latest_installed_tem_jdk_for_major_version: dies with 0 args" {
  run sdkman_jdks::get_formatted_latest_installed_tem_jdk_for_major_version < /dev/null
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "get_installed_tem_jdk_major_versions: numerically sorted unique installed majors" {
  stub_jdks_and_sdk
  run sdkman_jdks::get_installed_tem_jdk_major_versions
  assert_success
  assert_line --index 0 '17'
  assert_line --index 1 '21'
}

@test "get_installed_tem_jdk_major_versions: dies with args" {
  run sdkman_jdks::get_installed_tem_jdk_major_versions 'extra' < /dev/null
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "get_latest_installed_tem_jdk_major_version: returns highest installed major" {
  stub_jdks_and_sdk
  run sdkman_jdks::get_latest_installed_tem_jdk_major_version
  assert_success
  assert_output '21'
}

@test "get_latest_installed_tem_jdk_major_version: dies with args" {
  run sdkman_jdks::get_latest_installed_tem_jdk_major_version 'extra' < /dev/null
  assert_failure
  assert_output --partial 'Expected no arguments'
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

@test "check_installed_tem_jdk_major_version: dies with 0 args" {
  run sdkman_jdks::check_installed_tem_jdk_major_version < /dev/null
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
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

@test "is_tem_jdk_artifact_installed: dies with 0 args" {
  run sdkman_jdks::is_tem_jdk_artifact_installed < /dev/null
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "get_latest_installed_tem_jdk_artifact_id_for_major_version: returns artifact id" {
  stub_jdks_and_sdk
  run sdkman_jdks::get_latest_installed_tem_jdk_artifact_id_for_major_version 21
  assert_success
  assert_output '21.0.5-tem'
}

@test "get_latest_installed_tem_jdk_artifact_id_for_major_version: dies with 0 args" {
  run sdkman_jdks::get_latest_installed_tem_jdk_artifact_id_for_major_version < /dev/null
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- installing / setting default / pruning ----------

@test "install_latest_tem_jdk: installs latest available for major" {
  stub_jdks_and_sdk
  run sdkman_jdks::install_latest_tem_jdk 21
  assert_success
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_output 'install java 21.0.5-tem'
}

@test "install_latest_tem_jdk: dies with 0 args" {
  run sdkman_jdks::install_latest_tem_jdk < /dev/null
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
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

@test "install_latest_tem_jdks: dies with args" {
  run sdkman_jdks::install_latest_tem_jdks 'extra' < /dev/null
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "set_default_sdk_to_latest_installed_for_major_version: sets default to latest installed" {
  stub_jdks_and_sdk
  run sdkman_jdks::set_default_sdk_to_latest_installed_for_major_version 21
  assert_success
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_output 'default java 21.0.5-tem'
}

@test "set_default_sdk_to_latest_installed_for_major_version: dies with 0 args" {
  run sdkman_jdks::set_default_sdk_to_latest_installed_for_major_version < /dev/null
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
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
  # Current default is an older 17 patch while 21 is the highest installed major, so this asserts
  # both halves of the contract: major 17 is kept, and its latest installed patch is selected.
  fixture_installed_jdks '17.0.11-tem'
  fixture_default_symlink '17.0.10-tem'
  run sdkman_jdks::set_default_jdk_to_latest_patch_of_current_major
  assert_success
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_output 'default java 17.0.11-tem'
}

@test "set_default_jdk_to_latest_patch_of_current_major: falls back to highest installed major when no default set" {
  stub_jdks_and_sdk
  # setup() creates candidates/java with no current symlink
  run sdkman_jdks::set_default_jdk_to_latest_patch_of_current_major
  assert_success
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_output 'default java 21.0.5-tem'
}

@test "set_default_jdk_to_latest_patch_of_current_major: dies with args" {
  run sdkman_jdks::set_default_jdk_to_latest_patch_of_current_major 'extra' < /dev/null
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "prune_tem_jdks_for_major_version: uninstalls all installed for major except latest available" {
  stub_jdks_and_sdk
  run sdkman_jdks::prune_tem_jdks_for_major_version 21
  assert_success
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_output 'uninstall java 21.0.3-tem'
}

@test "prune_tem_jdks_for_major_version: dies with 0 args" {
  run sdkman_jdks::prune_tem_jdks_for_major_version < /dev/null
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "prune_tem_jdks: prunes across every installed major" {
  stub_jdks_and_sdk
  run sdkman_jdks::prune_tem_jdks
  assert_success
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_output --partial 'uninstall java 21.0.3-tem'
}

@test "prune_tem_jdks: dies with args" {
  run sdkman_jdks::prune_tem_jdks 'extra' < /dev/null
  assert_failure
  assert_output --partial 'Expected no arguments'
}
