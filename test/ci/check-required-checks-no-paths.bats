setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-required-checks-no-paths"
  WF="${BATS_TEST_TMPDIR}/wf"
  mkdir -p "${WF}"
}

@test "passes when no PR workflow has path filters" {
  cat > "${WF}/a.yml" << 'EOF'
on:
  pull_request:
    branches: [main]
jobs:
  x:
    steps:
      - run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_success
}

@test "fails when a PR workflow declares paths:" {
  cat > "${WF}/a.yml" << 'EOF'
on:
  pull_request:
    branches: [main]
    paths:
      - 'src/**'
jobs:
  x:
    steps:
      - run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
  assert_output --partial 'paths'
}

@test "fails when a PR workflow declares paths-ignore:" {
  cat > "${WF}/a.yml" << 'EOF'
on:
  pull_request:
    paths-ignore:
      - 'docs/**'
jobs:
  x:
    steps:
      - run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
}

@test "ignores path filters on non-pull_request triggers" {
  cat > "${WF}/a.yml" << 'EOF'
on:
  push:
    paths:
      - 'src/**'
jobs:
  x:
    steps:
      - run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_success
}

@test "dies when given an argument" {
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}
