setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-uses-sha-pinned"
  WF="${BATS_TEST_TMPDIR}/wf"
  mkdir -p "${WF}"
  # Isolate existing cases from the real .github/actions tree.
  export ACTIONS_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/empty-actions"
}

@test "passes when every uses is 40-hex SHA-pinned" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_success
}

@test "passes for local ./ composite refs" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    steps:
      - uses: ./.github/actions/local-thing
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_success
}

@test "fails on a version-tag ref" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    steps:
      - uses: actions/checkout@v4
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
  assert_output --partial 'not SHA-pinned'
}

@test "fails on a short (non-40-hex) sha" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    steps:
      - uses: actions/checkout@de0fac2
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
}

@test "passes on empty workflows dir" {
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_success
}

@test "dies when given an argument" {
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}" unexpected
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "scans .github/actions and fails on an unpinned composite uses" {
  local actions="${BATS_TEST_TMPDIR}/actions/setup"
  mkdir -p "${actions}"
  cat > "${actions}/action.yml" << 'EOF'
runs:
  using: composite
  steps:
    - uses: actions/checkout@v4
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" ACTIONS_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/actions" \
    run "${CHECK}"
  assert_failure
  assert_output --partial 'not SHA-pinned'
}

@test "passes when composite uses are SHA-pinned" {
  local actions="${BATS_TEST_TMPDIR}/actions/setup"
  mkdir -p "${actions}"
  cat > "${actions}/action.yml" << 'EOF'
runs:
  using: composite
  steps:
    - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" ACTIONS_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/actions" \
    run "${CHECK}"
  assert_success
}

@test "passes when the actions dir is absent" {
  WORKFLOWS_DIR_OVERRIDE="${WF}" ACTIONS_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/nope" \
    run "${CHECK}"
  assert_success
}
