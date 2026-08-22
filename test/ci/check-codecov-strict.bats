setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-codecov-strict"
  WF="${BATS_TEST_TMPDIR}/wf"
  mkdir -p "${WF}"
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

@test "passes against the real repository workflows" {
  run_check "${CHECK}"
  assert_success
}

@test "dies with 1 arg" {
  run_check "${CHECK}" 'unexpected'
  assert_failure
  assert_output --partial 'Expected no arguments'
}
