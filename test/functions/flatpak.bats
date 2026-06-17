#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${REPO_DIR}/test/test_helper/path_shim.bash"
  # shellcheck disable=SC1091
  source "${REPO_DIR}/test/test_helper/cli_shim.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/path.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/commands.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/misc.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/flatpak.bash"

  # commands::* strips SCRIPTS_DIR/main and SCRIPTS_DIR/other from PATH.
  # Redirect SCRIPTS_DIR to a tmpdir so the real repo's main/other aren't stripped.
  export REAL_SCRIPTS_DIR="${SCRIPTS_DIR}"
  SCRIPTS_DIR="${BATS_TEST_TMPDIR}"
  mkdir --parents "${SCRIPTS_DIR}/main" "${SCRIPTS_DIR}/other"
}

# ---------- flatpak::assert_installed ----------

@test "assert_installed: 0 args dies" {
  run flatpak::assert_installed
  assert_failure
}

@test "assert_installed: 2 args dies" {
  run flatpak::assert_installed 'a' 'b'
  assert_failure
}

@test "assert_installed: flatpak missing dies" {
  # No flatpak shim installed; commands::assert_executable_exists should die.
  run flatpak::assert_installed 'org.example.App'
  assert_failure
}

@test "assert_installed: flatpak info exits 0 -> success" {
  cli_shim::record_with_output 'flatpak' '' 0
  run flatpak::assert_installed 'org.example.App'
  assert_success
}

@test "assert_installed: flatpak info exits 1 -> dies with message" {
  cli_shim::record_with_output 'flatpak' '' 1
  run flatpak::assert_installed 'org.example.App'
  assert_failure
  assert_output --partial 'Flatpak application not installed: org.example.App'
}

# ---------- flatpak::exec_gui ----------

@test "exec_gui: 0 args dies" {
  run flatpak::exec_gui
  assert_failure
}

@test "exec_gui: missing flatpak dies" {
  run flatpak::exec_gui 'org.example.App'
  assert_failure
}

@test "exec_gui: not installed -> dies before exec" {
  cli_shim::record_with_output 'flatpak' '' 1
  cli_shim::record 'setsid'
  run flatpak::exec_gui 'org.example.App' '--foo'
  assert_failure
  assert_output --partial 'Flatpak application not installed: org.example.App'
  [[ ! -f "${BATS_TEST_TMPDIR}/setsid.calls" ]]
}

@test "exec_gui: installed -> execs setsid --fork flatpak run <id> <args>" {
  cli_shim::record_with_output 'flatpak' '' 0
  cli_shim::record 'setsid'
  run flatpak::exec_gui 'org.example.App' 'file.txt' '--flag'
  assert_success
  run cat "${BATS_TEST_TMPDIR}/setsid.calls"
  assert_output '--fork flatpak run org.example.App file.txt --flag'
}

@test "exec_gui: installed, no forwarded args -> execs setsid --fork flatpak run <id>" {
  cli_shim::record_with_output 'flatpak' '' 0
  cli_shim::record 'setsid'
  run flatpak::exec_gui 'org.example.App'
  assert_success
  run cat "${BATS_TEST_TMPDIR}/setsid.calls"
  assert_output '--fork flatpak run org.example.App'
}

# ---------- flatpak::exec ----------

@test "exec: 0 args dies" {
  run flatpak::exec
  assert_failure
}

@test "exec: missing flatpak dies" {
  run flatpak::exec 'org.example.App'
  assert_failure
}

@test "exec: not installed -> dies, flatpak run not invoked" {
  cli_shim::record_with_output 'flatpak' '' 1
  run flatpak::exec 'org.example.App' '--foo'
  assert_failure
  run cat "${BATS_TEST_TMPDIR}/flatpak.calls"
  refute_output --partial 'run org.example.App'
}

@test "exec: installed -> execs flatpak run <id> <args>" {
  cli_shim::record_with_output 'flatpak' '' 0
  run flatpak::exec 'org.example.App' 'doc.pdf' '--readonly'
  assert_success
  run cat "${BATS_TEST_TMPDIR}/flatpak.calls"
  assert_line 'info org.example.App'
  assert_line 'run org.example.App doc.pdf --readonly'
}

@test "exec: installed, no forwarded args -> execs flatpak run <id>" {
  cli_shim::record_with_output 'flatpak' '' 0
  run flatpak::exec 'org.example.App'
  assert_success
  run cat "${BATS_TEST_TMPDIR}/flatpak.calls"
  assert_line 'info org.example.App'
  assert_line 'run org.example.App'
}
