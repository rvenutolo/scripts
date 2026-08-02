#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/misc.bash"
}

# `misc::exec_gui` uses `exec setsid --fork ... > /dev/null 2>&1`, which replaces
# the calling process. Direct invocation inside a test would terminate the bats
# worker. Tests run the helper inside `bash -c` so the subshell is what gets
# replaced, with a path_shim'd `setsid` that records its args to a file
# (bypassing the redirected stdout/stderr) before exiting cleanly.

@test "exec_gui: forwards single arg to setsid --fork" {
  local calls_file="${BATS_TEST_TMPDIR}/setsid_calls"
  path_shim::add setsid "printf '%s\n' \"\$*\" > '${calls_file}'"
  run bash -c "
    PATH='${BATS_TEST_TMPDIR}/bin:${PATH}'
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/misc.bash'
    misc::exec_gui foo
  "
  assert_success
  [[ -f "${calls_file}" ]]
  run cat "${calls_file}"
  assert_output '--fork foo'
}

@test "exec_gui: forwards multiple args to setsid --fork verbatim" {
  local calls_file="${BATS_TEST_TMPDIR}/setsid_calls"
  path_shim::add setsid "printf '%s\n' \"\$*\" > '${calls_file}'"
  run bash -c "
    PATH='${BATS_TEST_TMPDIR}/bin:${PATH}'
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/misc.bash'
    misc::exec_gui foo bar baz
  "
  assert_success
  run cat "${calls_file}"
  assert_output '--fork foo bar baz'
}

@test "exec_gui: passes args containing url-like characters verbatim" {
  local calls_file="${BATS_TEST_TMPDIR}/setsid_calls"
  path_shim::add setsid "printf '%s\n' \"\$*\" > '${calls_file}'"
  run bash -c "
    PATH='${BATS_TEST_TMPDIR}/bin:${PATH}'
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/misc.bash'
    misc::exec_gui xdg-open 'https://example.com/path?q=1'
  "
  assert_success
  run cat "${calls_file}"
  assert_output '--fork xdg-open https://example.com/path?q=1'
}

@test "exec_gui: redirects stdout and stderr to /dev/null" {
  local calls_file="${BATS_TEST_TMPDIR}/setsid_calls"
  # Shim prints loudly to stdout AND stderr, and ALSO records to the file so we
  # know it ran. If exec_gui's redirect works, the loud output never reaches us.
  path_shim::add setsid "
    printf 'STDOUT-LEAK\n'
    printf 'STDERR-LEAK\n' >&2
    printf '%s\n' \"\$*\" > '${calls_file}'
  "
  run bash -c "
    PATH='${BATS_TEST_TMPDIR}/bin:${PATH}'
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/misc.bash'
    misc::exec_gui some-gui-app
  "
  assert_success
  refute_output --partial 'STDOUT-LEAK'
  refute_output --partial 'STDERR-LEAK'
  [[ -f "${calls_file}" ]]
}

@test "exec_gui: dies with no args" {
  run misc::exec_gui
  assert_failure
  assert_output --partial 'Expected at least 1 argument'
}

@test "exec_gui: --version runs attached, without setsid" {
  local calls_file="${BATS_TEST_TMPDIR}/setsid_calls"
  path_shim::add setsid "printf '%s\n' \"\$*\" > '${calls_file}'"
  path_shim::add some-gui-app "printf 'REAL-OUTPUT\n'"
  run bash -c "
    PATH='${BATS_TEST_TMPDIR}/bin:${PATH}'
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/misc.bash'
    misc::exec_gui some-gui-app --version
  "
  assert_success
  assert_output --partial 'REAL-OUTPUT'
  [[ ! -f "${calls_file}" ]]
}

@test "exec_gui: --help runs attached, without setsid" {
  local calls_file="${BATS_TEST_TMPDIR}/setsid_calls"
  path_shim::add setsid "printf '%s\n' \"\$*\" > '${calls_file}'"
  path_shim::add some-gui-app "printf 'HELP-TEXT\n'"
  run bash -c "
    PATH='${BATS_TEST_TMPDIR}/bin:${PATH}'
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/misc.bash'
    misc::exec_gui some-gui-app --help
  "
  assert_success
  assert_output --partial 'HELP-TEXT'
  [[ ! -f "${calls_file}" ]]
}

@test "exec_gui: probe branch does not redirect stdout or stderr" {
  path_shim::add some-gui-app "
    printf 'STDOUT-VISIBLE\n'
    printf 'STDERR-VISIBLE\n' >&2
  "
  run bash -c "
    PATH='${BATS_TEST_TMPDIR}/bin:${PATH}'
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/misc.bash'
    misc::exec_gui some-gui-app --version
  "
  assert_success
  assert_output --partial 'STDOUT-VISIBLE'
  assert_output --partial 'STDERR-VISIBLE'
}

@test "exec_gui: probe branch propagates the command's exit code" {
  path_shim::add some-gui-app 'exit 3'
  run bash -c "
    PATH='${BATS_TEST_TMPDIR}/bin:${PATH}'
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/misc.bash'
    misc::exec_gui some-gui-app --version
  "
  assert_failure 3
}

@test "exec_gui: probe branch forwards all args verbatim" {
  path_shim::add some-gui-app "printf 'ARGS:%s\n' \"\$*\""
  run bash -c "
    PATH='${BATS_TEST_TMPDIR}/bin:${PATH}'
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/misc.bash'
    misc::exec_gui some-gui-app --version --extra foo
  "
  assert_success
  assert_output --partial 'ARGS:--version --extra foo'
}

@test "exec_gui: non-probe args still detach through setsid --fork" {
  local calls_file="${BATS_TEST_TMPDIR}/setsid_calls"
  path_shim::add setsid "printf '%s\n' \"\$*\" > '${calls_file}'"
  run bash -c "
    PATH='${BATS_TEST_TMPDIR}/bin:${PATH}'
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/misc.bash'
    misc::exec_gui some-gui-app --verbose file.txt
  "
  assert_success
  run cat "${calls_file}"
  assert_output '--fork some-gui-app --verbose file.txt'
}
