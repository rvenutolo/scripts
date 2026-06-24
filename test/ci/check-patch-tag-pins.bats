setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-patch-tag-pins"
  WF="${BATS_TEST_TMPDIR}/wf"
  mkdir -p "${WF}"
  # Isolate existing cases from the real .github/actions tree.
  export ACTIONS_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/empty-actions"
}

@test "passes on a good # v6.0.2 pin" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_success
}

@test "passes on bare-major comments # v22 and # v7" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    steps:
      - uses: actions/setup-node@1111111111111111111111111111111111111111 # v22
      - uses: actions/cache@2222222222222222222222222222222222222222 # v7
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_success
}

@test "fails on a SHA pin with no trailing comment" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
  assert_output --partial 'missing/!matching version comment'
}

@test "fails on a SHA pin with a malformed comment" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # wip
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
  assert_output --partial 'missing/!matching version comment'
}

@test "skips a local ./ composite ref" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    steps:
      - uses: ./.github/actions/local-thing
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_success
}

@test "skips a non-pinned @v4 ref (sibling's concern)" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    steps:
      - uses: actions/checkout@v4
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_success
}

@test "scans .github/actions and fails on a bare composite pin" {
  local actions="${BATS_TEST_TMPDIR}/actions/setup"
  mkdir -p "${actions}"
  cat > "${actions}/action.yml" << 'EOF'
runs:
  using: composite
  steps:
    - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" ACTIONS_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/actions" \
    run "${CHECK}"
  assert_failure
  assert_output --partial 'missing/!matching version comment'
}

@test "scans .github/actions and passes on a well-commented composite pin" {
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

@test "passes on empty workflows dir" {
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_success
}

@test "passes when the actions dir is absent" {
  WORKFLOWS_DIR_OVERRIDE="${WF}" ACTIONS_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/nope" \
    run "${CHECK}"
  assert_success
}

@test "dies when given an argument" {
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}" unexpected
  assert_failure
  assert_output --partial 'Expected no arguments'
}
