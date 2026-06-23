setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-job-timeout-minutes"
  WF="${BATS_TEST_TMPDIR}/wf"
  mkdir -p "${WF}"
}

@test "passes when every job has a positive-int timeout-minutes" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 10
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 20
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_success
}

@test "fails when a job is missing timeout-minutes" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    runs-on: ubuntu-latest
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
  assert_output --partial 'no timeout-minutes'
}

@test "fails when timeout-minutes is 0" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 0
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
  assert_output --partial 'not a positive integer'
}

@test "fails when timeout-minutes is negative" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: -5
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
  assert_output --partial 'not a positive integer'
}

@test "fails when timeout-minutes is non-numeric" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: abc
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
  assert_output --partial 'not a positive integer'
}

@test "checks every job, not just the first" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  good:
    runs-on: ubuntu-latest
    timeout-minutes: 10
  bad:
    runs-on: ubuntu-latest
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
}

@test "dies when given an argument" {
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}
