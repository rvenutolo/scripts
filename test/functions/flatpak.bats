# shellcheck disable=SC2030,SC2031 # BATS isolates each @test in its own subshell; the PATH mutations below are intentional and correctly scoped per-test

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
  # Capture PATH so teardown can restore it. The missing-flatpak tests below pin PATH
  # to an empty dir, and BATS's own cleanup shells out to rm — same reason
  # test/functions/path.bats carries this pair.
  ORIGINAL_PATH="${PATH}"
}

teardown() {
  PATH="${ORIGINAL_PATH}"
}

# ---------- flatpak::assert_installed ----------

@test "assert_installed: 0 args dies" {
  run flatpak::assert_installed
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "assert_installed: 2 args dies" {
  run flatpak::assert_installed 'a' 'b'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "assert_installed: flatpak missing dies" {
  # Pin PATH to an empty dir for the duration of the call so flatpak is genuinely
  # absent and commands::assert_executable_exists dies before `flatpak info` is
  # reached. Without the pin this exercises the missing-binary path only on hosts
  # that happen not to have flatpak installed, and a different path everywhere else.
  # PATH is restored immediately: bats' own teardown shells out to rm.
  mkdir --parents "${BATS_TEST_TMPDIR}/bin"
  PATH="${BATS_TEST_TMPDIR}/bin"
  run flatpak::assert_installed 'org.example.App'
  assert_failure
  assert_output --partial 'flatpak executable not found'
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
  assert_output --partial 'Expected at least 1 argument'
}

@test "exec_gui: missing flatpak dies" {
  # See "assert_installed: flatpak missing dies" for why PATH is pinned and restored.
  mkdir --parents "${BATS_TEST_TMPDIR}/bin"
  PATH="${BATS_TEST_TMPDIR}/bin"
  run flatpak::exec_gui 'org.example.App'
  assert_failure
  assert_output --partial 'flatpak executable not found'
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

@test "exec_gui: --version runs attached, no setsid" {
  cli_shim::record_with_output 'flatpak' '' 0
  cli_shim::record 'setsid'
  run flatpak::exec_gui 'org.example.App' '--version'
  assert_success
  run cat "${BATS_TEST_TMPDIR}/flatpak.calls"
  assert_output --partial 'run org.example.App --version'
  [[ ! -f "${BATS_TEST_TMPDIR}/setsid.calls" ]]
}

@test "exec_gui: --help runs attached, no setsid" {
  cli_shim::record_with_output 'flatpak' '' 0
  cli_shim::record 'setsid'
  run flatpak::exec_gui 'org.example.App' '--help'
  assert_success
  run cat "${BATS_TEST_TMPDIR}/flatpak.calls"
  assert_output --partial 'run org.example.App --help'
  [[ ! -f "${BATS_TEST_TMPDIR}/setsid.calls" ]]
}

@test "exec_gui: probe flag still requires the app to be installed" {
  cli_shim::record_with_output 'flatpak' '' 1
  cli_shim::record 'setsid'
  run flatpak::exec_gui 'org.example.App' '--version'
  assert_failure
  assert_output --partial 'Flatpak application not installed: org.example.App'
  [[ ! -f "${BATS_TEST_TMPDIR}/setsid.calls" ]]
}

# ---------- flatpak::exec ----------

@test "exec: 0 args dies" {
  run flatpak::exec
  assert_failure
  assert_output --partial 'Expected at least 1 argument'
}

@test "exec: missing flatpak dies" {
  # See "assert_installed: flatpak missing dies" for why PATH is pinned and restored.
  mkdir --parents "${BATS_TEST_TMPDIR}/bin"
  PATH="${BATS_TEST_TMPDIR}/bin"
  run flatpak::exec 'org.example.App'
  assert_failure
  assert_output --partial 'flatpak executable not found'
}

@test "exec: not installed -> dies, flatpak run not invoked" {
  cli_shim::record_with_output 'flatpak' '' 1
  run flatpak::exec 'org.example.App' '--foo'
  assert_failure
  assert_output --partial 'Flatpak application not installed: org.example.App'
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
