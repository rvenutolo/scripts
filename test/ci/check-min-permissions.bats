setup() {
  load '../test_helper/common'
  CHECK="${SCRIPTS_DIR}/.ci/check-min-permissions"
  WF="${BATS_TEST_TMPDIR}/wf"
  mkdir -p "${WF}"
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
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
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
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
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
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
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
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
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
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
  assert_output --partial 'missing'
}

@test "dies when given an argument" {
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}
