bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  WRAPPER="${REPO_DIR}/scripts/non-interactive/claude"
  # A stub `claude` that prints the PATH it was exec'd with. path_shim prepends
  # its bin dir to PATH, and commands::executable_path strips only the repo's
  # non-interactive/interactive/other dirs, so the stub is what resolves.
  path_shim::mkbin
  cat > "${BATS_TEST_TMPDIR}/bin/claude" << 'EOF'
#!/usr/bin/env bash
printf '%s\n' "${PATH}"
EOF
  chmod +x "${BATS_TEST_TMPDIR}/bin/claude"
  FIX="${BATS_TEST_TMPDIR}/fixture"
  mkdir --parents "${FIX}/real-shims"
  ln --symbolic "${FIX}/real-shims" "${FIX}/link-shims"
  REAL_SHIMS="$(cd -P -- "${FIX}/real-shims" && pwd -P)"
  # The wrapper derives the config dir from PWD unless CLAUDE_CONFIG_DIR is
  # set; set it so the test needs neither WORK_PROJECTS_DIR nor XDG_CONFIG_HOME.
  export CLAUDE_CONFIG_DIR="${BATS_TEST_TMPDIR}/cfg"
}

# run_wrapper <shims-dir> — BASH_ENV=SAFE_BASH_ENV so a child bash does not
# re-source ~/.bashrc and re-prepend the real PATH ahead of the stub claude.
run_wrapper() {
  run env BASH_ENV="${SAFE_BASH_ENV}" \
    CLAUDE_SHIMS_DIR_OVERRIDE="$1" "${WRAPPER}"
}

@test "prepends the physical shim dir as the first PATH entry" {
  run_wrapper "${FIX}/link-shims"
  assert_success
  assert_line --index 0 --regexp "^${REAL_SHIMS}:"
  refute_output --partial 'guard inactive'
}

@test "warns and still execs claude when the shim dir is missing" {
  run_wrapper "${FIX}/absent"
  assert_success
  assert_output --partial 'claude shims dir missing'
  assert_output --partial 'guard inactive'
  refute_output --partial "${FIX}/absent:"
}

@test "resolves claude before the prepend: a claude inside the shim dir is never chosen" {
  cat > "${FIX}/real-shims/claude" << 'EOF'
#!/usr/bin/env bash
printf 'SHIM_CLAUDE_RAN\n'
EOF
  chmod +x "${FIX}/real-shims/claude"
  run_wrapper "${FIX}/real-shims"
  assert_success
  refute_output --partial 'SHIM_CLAUDE_RAN'
  assert_line --index 0 --regexp "^${REAL_SHIMS}:"
}
