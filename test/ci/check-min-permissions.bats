setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-min-permissions"
  WF="${BATS_TEST_TMPDIR}/wf"
  mkdir -p "${WF}"
}

# .ci/check-min-permissions derives its own repo root via
# `git rev-parse --show-toplevel`. common.bash's #248 hardening leaves CWD at
# BATS_TEST_TMPDIR (outside any git repo) by design, so cd into REPO_DIR before
# every invocation — this test targets the real repo.
run_check() {
  cd "${REPO_DIR}" || return 1
  run "$@"
}

@test "passes: empty top-level + per-job blocks" {
  cat > "${WF}/a.yml" << 'EOF'
permissions: {}
jobs:
  build:
    permissions:
      contents: read
    steps:
      - run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_success
}

@test "fails: missing top-level permissions" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    permissions:
      contents: read
    steps:
      - run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'missing top-level'
}

@test "fails: non-empty top-level permissions" {
  cat > "${WF}/a.yml" << 'EOF'
permissions:
  contents: read
jobs:
  build:
    permissions:
      contents: read
    steps:
      - run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'non-empty'
}

@test "fails: scalar top-level permissions" {
  cat > "${WF}/a.yml" << 'EOF'
permissions: read-all
jobs:
  build:
    permissions:
      contents: read
    steps:
      - run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
}

@test "fails: a job missing its permissions block" {
  cat > "${WF}/a.yml" << 'EOF'
permissions: {}
jobs:
  build:
    steps:
      - run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'missing'
}

@test "dies when given an argument" {
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}
