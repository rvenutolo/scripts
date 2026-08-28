bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  WRAPPER="${REPO_DIR}/scripts/non-interactive/claude"
  # A stub `claude` that prints the PATH it was exec'd with, then the pins the
  # wrapper applies. path_shim prepends its bin dir to PATH, and
  # commands::executable_path strips only the repo's non-interactive/interactive/other
  # dirs, so the stub is what resolves. PATH stays the first line: the PATH-prepend
  # tests below assert on index 0.
  path_shim::mkbin
  cat > "${BATS_TEST_TMPDIR}/bin/claude" << 'EOF'
#!/usr/bin/env bash
printf '%s\n' "${PATH}"
printf 'MODEL=%s\n' "${ANTHROPIC_MODEL-}"
printf 'ARGS=%s\n' "$*"
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

# run_wrapper <shims-dir> [args...] — BASH_ENV=SAFE_BASH_ENV so a child bash does
# not re-source ~/.bashrc and re-prepend the real PATH ahead of the stub claude.
# ANTHROPIC_MODEL is unset so the wrapper's own default is what the stub reports;
# the ambient environment carries one, because this suite runs under the wrapper.
run_wrapper() {
  local -r shims="$1"
  shift
  run env --unset=ANTHROPIC_MODEL BASH_ENV="${SAFE_BASH_ENV}" \
    CLAUDE_SHIMS_DIR_OVERRIDE="${shims}" "${WRAPPER}" "$@"
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

@test "pins the model to opus[1m] when ANTHROPIC_MODEL is unset" {
  # Claude Code persists a /model choice into settings.json, so without this pin a
  # one-off model switch becomes every later session's default.
  run_wrapper "${FIX}/real-shims"
  assert_success
  assert_line 'MODEL=opus[1m]'
}

@test "an already-set ANTHROPIC_MODEL is honored rather than overwritten" {
  run env ANTHROPIC_MODEL='sonnet' BASH_ENV="${SAFE_BASH_ENV}" \
    CLAUDE_SHIMS_DIR_OVERRIDE="${FIX}/real-shims" "${WRAPPER}"
  assert_success
  assert_line 'MODEL=sonnet'
}

@test "passes --effort high ahead of the caller's arguments" {
  # Same rationale as the model pin: /effort writes its choice into settings.json.
  run_wrapper "${FIX}/real-shims" --print 'hello'
  assert_success
  assert_line 'ARGS=--effort high --print hello'
}

@test "the pinned effort precedes a caller's own --effort, which wins last" {
  # Claude Code parses --effort last-wins, so the caller's value must come second.
  run_wrapper "${FIX}/real-shims" --effort max
  assert_success
  assert_line 'ARGS=--effort high --effort max'
}

@test "passes --effort high even with no caller arguments" {
  run_wrapper "${FIX}/real-shims"
  assert_success
  assert_line 'ARGS=--effort high'
}
