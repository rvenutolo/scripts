setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  load '../test_helper/cli_shim'
  SCRIPT="${REPO_DIR}/run-install-scripts"
  INSTALL="${BATS_TEST_TMPDIR}/install"
  FAKE_HOME="${BATS_TEST_TMPDIR}/home"
  mkdir -p "${INSTALL}" "${FAKE_HOME}"
  cli_shim::record sudo
}

# Drop an executable fixture that echoes a marker when run.
make_script() {
  local -r name="$1"
  local -r exit_code="${2:-0}"
  printf '#!/usr/bin/env bash\nprintf "RAN:%s\\n" "%s"\nexit %s\n' '%s' "${name}" "${exit_code}" \
    > "${INSTALL}/${name}"
  chmod +x "${INSTALL}/${name}"
}

# Drop a non-executable marker file, the convention used to gate a script off.
make_marker() {
  local -r name="$1"
  printf '#!/usr/bin/env bash\nprintf "RAN:%s\\n" "%s"\n' '%s' "${name}" > "${INSTALL}/${name}"
  chmod -x "${INSTALL}/${name}"
}

run_runner() {
  INSTALL_DIR_OVERRIDE="${INSTALL}" HOME="${FAKE_HOME}" run "${SCRIPT}" "$@"
}

@test "runs executables in LC_COLLATE=C order" {
  make_script '20_beta'
  make_script '05_zero'
  make_script '10_alpha'
  run_runner
  assert_success
  # Assert relative ordering of the runner's own log lines.
  local first second third
  first="$(printf '%s\n' "${output}" | grep --line-number 'Running: 05_zero' | cut --delimiter=: --fields=1)"
  second="$(printf '%s\n' "${output}" | grep --line-number 'Running: 10_alpha' | cut --delimiter=: --fields=1)"
  third="$(printf '%s\n' "${output}" | grep --line-number 'Running: 20_beta' | cut --delimiter=: --fields=1)"
  [[ "${first}" -lt "${second}" ]]
  [[ "${second}" -lt "${third}" ]]
}

@test "skips non-executable files" {
  make_script '10_alpha'
  make_marker '00_DISTRO_PACKAGES'
  run_runner
  assert_success
  assert_output --partial '10_alpha'
  refute_output --partial '00_DISTRO_PACKAGES'
}

@test "propagates a failing script and stops" {
  make_script '10_alpha'
  make_script '20_beta' 1
  make_script '30_gamma'
  run_runner
  assert_failure
  assert_output --partial 'Running: 20_beta'
  refute_output --partial 'Running: 30_gamma'
}

@test "validates sudo before iterating" {
  make_script '10_alpha'
  INSTALL_DIR_OVERRIDE="${INSTALL}" HOME="${FAKE_HOME}" "${SCRIPT}"
  assert_equal "$(cli_shim::calls sudo)" '--validate'
}

@test "succeeds with an empty install dir" {
  run_runner
  assert_success
}

@test "does not require ~/.profile to exist" {
  # FAKE_HOME has no .profile; the runner must treat that as fine.
  make_script '10_alpha'
  run_runner
  assert_success
}

@test "dies when given an argument" {
  run_runner oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "--help exits 0" {
  run_runner --help
  assert_success
}

# The absent-.profile case above is only half the contract. The runners source
# ~/.profile precisely so the provisioning scripts they invoke inherit the user's
# environment — SCRIPTS_DIR, the XDG vars, PERSONAL_PROJECTS_DIR — which CLAUDE.md
# treats as guaranteed to be set by the time any script runs. Asserting that an
# export from .profile reaches the fixture script pins that end to end, rather than
# just proving the source line did not error.
@test "sources ~/.profile and its exports reach the scripts it runs" {
  printf '%s\n' 'export PROFILE_SENTINEL=sourced' > "${FAKE_HOME}/.profile"
  cat > "${INSTALL}/10_probe" << 'EOF'
#!/usr/bin/env bash
printf 'SENTINEL:%s\n' "${PROFILE_SENTINEL:-unset}"
EOF
  chmod +x "${INSTALL}/10_probe"
  run_runner
  assert_success
  assert_output --partial 'SENTINEL:sourced'
}
