setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-checkout-persist-credentials"
  WF="${BATS_TEST_TMPDIR}/wf"
  ACT="${BATS_TEST_TMPDIR}/actions/myaction"
  mkdir -p "${WF}" "${ACT}"
}

# Run the check with both override seams pointed at the test tmpdirs.
run_check() {
  WORKFLOWS_DIR_OVERRIDE="${WF}" ACTIONS_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/actions" run "${CHECK}" "$@"
}

@test "passes when checkout sets persist-credentials: false" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false
EOF
  run_check
  assert_success
}

@test "fails when checkout sets persist-credentials: true" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: true
EOF
  run_check
  assert_failure
  assert_output --partial 'a.yml'
  assert_output --partial 'persist-credentials'
}

@test "fails when checkout omits the persist-credentials key" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
EOF
  run_check
  assert_failure
  assert_output --partial 'a.yml'
}

@test "fails when checkout has no with block at all" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - uses: actions/checkout@v4
EOF
  run_check
  assert_failure
}

@test "fails when persist-credentials is the string \"false\" (strict bool)" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: "false"
EOF
  run_check
  assert_failure
}

@test "fails on a non-compliant checkout inside a composite action" {
  cat > "${ACT}/action.yml" << 'EOF'
runs:
  using: composite
  steps:
    - uses: actions/checkout@v4
      with:
        persist-credentials: true
      shell: bash
EOF
  run_check
  assert_failure
  assert_output --partial 'action.yml'
}

@test "passes on a compliant checkout inside a composite action" {
  cat > "${ACT}/action.yml" << 'EOF'
runs:
  using: composite
  steps:
    - uses: actions/checkout@v4
      with:
        persist-credentials: false
EOF
  run_check
  assert_success
}

@test "ignores a non-checkout step missing persist-credentials" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - uses: actions/setup-node@v4
        with:
          node-version: 20
EOF
  run_check
  assert_success
}

@test "ignores a plain run step with no uses" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - run: echo hello
EOF
  run_check
  assert_success
}

@test "checks every file, not just the first" {
  cat > "${WF}/good.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false
EOF
  cat > "${WF}/bad.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: true
EOF
  run_check
  assert_failure
  assert_output --partial 'bad.yml'
}

@test "checks every step in a job, not just the first" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false
      - uses: actions/checkout@v4
        with:
          persist-credentials: true
EOF
  run_check
  assert_failure
}

@test "exits 0 when both scan dirs are absent" {
  WORKFLOWS_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/nope" \
    ACTIONS_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/nope2" run "${CHECK}"
  assert_success
}

@test "dies when given an argument" {
  run_check oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}
