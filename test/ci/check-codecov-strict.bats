setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-codecov-strict"
  WF="${BATS_TEST_TMPDIR}/wf"
  ACT="${BATS_TEST_TMPDIR}/actions/coverage"
  mkdir -p "${WF}" "${ACT}"
  # Point the composite scan at an empty fixture by default so a test that only
  # overrides the workflows dir does not silently pull in the real
  # .github/actions tree. The real-repo test below unsets it again.
  export ACTIONS_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/actions"
}

# .ci/check-codecov-strict derives its own repo root via
# `git rev-parse --show-toplevel`. common.bash's #248 hardening leaves CWD at
# BATS_TEST_TMPDIR (outside any git repo) by design, so cd into REPO_DIR before
# every invocation.
run_check() {
  cd "${REPO_DIR}" || return 1
  run "$@"
}

@test "passes: codecov step with fail_ci_if_error true and no bypasses" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  coverage:
    steps:
      - uses: codecov/codecov-action@abc123 # v7.0.0
        with:
          files: coverage/coverage.xml
          fail_ci_if_error: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_success
}

@test "fails: fail_ci_if_error explicitly false" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  coverage:
    steps:
      - uses: codecov/codecov-action@abc123
        with:
          fail_ci_if_error: false
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'fail_ci_if_error must be true'
  assert_output --partial 'found: false'
}

@test "fails: fail_ci_if_error absent" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  coverage:
    steps:
      - uses: codecov/codecov-action@abc123
        with:
          files: coverage/coverage.xml
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'fail_ci_if_error must be true'
  assert_output --partial 'found: null'
}

@test "fails: step with no with: block at all" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  coverage:
    steps:
      - uses: codecov/codecov-action@abc123
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'fail_ci_if_error must be true'
}

@test "fails: skip_validation true" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  coverage:
    steps:
      - uses: codecov/codecov-action@abc123
        with:
          fail_ci_if_error: true
          skip_validation: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'skip_validation'
}

@test "fails: binary input set" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  coverage:
    steps:
      - uses: codecov/codecov-action@abc123
        with:
          fail_ci_if_error: true
          binary: /tmp/codecov
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'binary'
}

@test "fails: use_pypi true" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  coverage:
    steps:
      - uses: codecov/codecov-action@abc123
        with:
          fail_ci_if_error: true
          use_pypi: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'use_pypi'
}

@test "reports every violation in one run" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  coverage:
    steps:
      - uses: codecov/codecov-action@abc123
        with:
          skip_validation: true
          use_pypi: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'fail_ci_if_error must be true'
  assert_output --partial 'skip_validation'
  assert_output --partial 'use_pypi'
  assert_output --partial '3 codecov-action violation(s)'
}

@test "ignores workflows with no codecov step" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    steps:
      - uses: actions/checkout@abc123
      - run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_success
}

@test "tolerates a job with no steps and a file with no jobs" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  call:
    uses: ./.github/workflows/other.yml
EOF
  cat > "${WF}/b.yml" << 'EOF'
on: push
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_success
}

@test "passes against the real repository workflows and actions" {
  unset ACTIONS_DIR_OVERRIDE
  run_check "${CHECK}"
  assert_success
}

@test "dies with 1 arg" {
  run_check "${CHECK}" 'unexpected'
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "fails loudly on a workflow yq cannot parse" {
  # Regression for #290. The per-file helper runs inside a command substitution,
  # where bash unsets errexit unless inherit_errexit is set. A failing yq used to
  # leave the helper running past it, echoing a zero count, so the check exited 0
  # with the unparsable file never scanned.
  printf -- '- a\n- b\n' > "${WF}/seq.yml"
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure 1
}

@test "fails: composite action step with fail_ci_if_error false" {
  # #291: a codecov step moved into a composite must stay in scope. A composite
  # has no job, so the violation names the file alone.
  cat > "${ACT}/action.yml" << 'EOF'
name: coverage
runs:
  using: composite
  steps:
    - uses: codecov/codecov-action@abc123
      with:
        fail_ci_if_error: false
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'action.yml: fail_ci_if_error must be true (found: false)'
  refute_output --partial 'job'
}

@test "passes: composite action step with fail_ci_if_error true" {
  cat > "${ACT}/action.yml" << 'EOF'
name: coverage
runs:
  using: composite
  steps:
    - uses: codecov/codecov-action@abc123
      with:
        fail_ci_if_error: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_success
}

@test "fails: composite action step setting skip_validation" {
  cat > "${ACT}/action.yml" << 'EOF'
name: coverage
runs:
  using: composite
  steps:
    - uses: codecov/codecov-action@abc123
      with:
        fail_ci_if_error: true
        skip_validation: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'skip_validation bypasses CLI integrity checking'
}

@test "fails: composite action step setting binary" {
  cat > "${ACT}/action.yml" << 'EOF'
name: coverage
runs:
  using: composite
  steps:
    - uses: codecov/codecov-action@abc123
      with:
        fail_ci_if_error: true
        binary: ./codecov
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'binary bypasses CLI integrity checking'
}

@test "fails: composite action step setting use_pypi" {
  cat > "${ACT}/action.yml" << 'EOF'
name: coverage
runs:
  using: composite
  steps:
    - uses: codecov/codecov-action@abc123
      with:
        fail_ci_if_error: true
        use_pypi: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'use_pypi bypasses CLI integrity checking'
}

@test "a workflow violation still names its job" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  coverage:
    steps:
      - uses: codecov/codecov-action@abc123
        with:
          fail_ci_if_error: false
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'job coverage: fail_ci_if_error must be true'
}

@test "ignores a composite action with no codecov step" {
  cat > "${ACT}/action.yml" << 'EOF'
name: setup
runs:
  using: composite
  steps:
    - run: true
      shell: bash
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_success
}

@test "ignores an action that runs no steps at all" {
  cat > "${ACT}/action.yml" << 'EOF'
name: js-action
runs:
  using: node20
  main: index.js
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_success
}

@test "exits 0 when neither scan directory exists" {
  WORKFLOWS_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/nope" \
    ACTIONS_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/nope" run_check "${CHECK}"
  assert_success
}

@test "scans both directories in one run" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  coverage:
    steps:
      - uses: codecov/codecov-action@abc123
        with:
          fail_ci_if_error: false
EOF
  cat > "${ACT}/action.yml" << 'EOF'
name: coverage
runs:
  using: composite
  steps:
    - uses: codecov/codecov-action@abc123
      with:
        fail_ci_if_error: false
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'job coverage: fail_ci_if_error must be true'
  assert_output --partial 'action.yml: fail_ci_if_error must be true'
  assert_output --partial '2 codecov-action violation(s)'
}
