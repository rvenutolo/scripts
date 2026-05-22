setup() {
  load '../test_helper/common'
  CHECK="${SCRIPTS_DIR}/.ci/check-harden-runner-first"
  WF="${BATS_TEST_TMPDIR}/wf"
  mkdir -p "${WF}"
  HR='step-security/harden-runner@ab7a9404c0f3da075243ca237b5fac12c98deaa5'
}

@test "passes when harden-runner is the SHA-pinned first step" {
  cat > "${WF}/a.yml" << EOF
jobs:
  build:
    steps:
      - uses: ${HR}
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_success
}

@test "fails when first step is not harden-runner" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
  assert_output --partial 'first step'
}

@test "fails when first step has no uses (run step)" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    steps:
      - run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
  assert_output --partial 'no first-step'
}

@test "fails when harden-runner ref is not SHA-pinned" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    steps:
      - uses: step-security/harden-runner@v2
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
  assert_output --partial 'not SHA-pinned'
}

@test "checks every job, not just the first" {
  cat > "${WF}/a.yml" << EOF
jobs:
  good:
    steps:
      - uses: ${HR}
  bad:
    steps:
      - run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
}

@test "dies when given an argument" {
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}
