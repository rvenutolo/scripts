setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-workflow-concurrency"
  WF="${BATS_TEST_TMPDIR}/wf"
  mkdir -p "${WF}"
}

@test "passes when a workflow declares a non-empty concurrency.group" {
  cat > "${WF}/a.yml" << 'EOF'
concurrency:
  group: ci-main
  cancel-in-progress: true
on: push
jobs:
  build:
    runs-on: ubuntu-latest
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_success
}

@test "fails when concurrency is absent" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    runs-on: ubuntu-latest
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
  assert_output --partial 'no concurrency.group'
}

@test "fails when concurrency is present but group is missing" {
  cat > "${WF}/a.yml" << 'EOF'
concurrency:
  cancel-in-progress: true
on: push
jobs:
  build:
    runs-on: ubuntu-latest
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
  assert_output --partial 'no concurrency.group'
}

@test "fails when group is an empty string" {
  cat > "${WF}/a.yml" << 'EOF'
concurrency:
  group: ""
on: push
jobs:
  build:
    runs-on: ubuntu-latest
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
  assert_output --partial 'no concurrency.group'
}

@test "passes when cancel-in-progress is absent (not enforced)" {
  cat > "${WF}/a.yml" << 'EOF'
concurrency:
  group: ci-main
on: push
jobs:
  build:
    runs-on: ubuntu-latest
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_success
}

@test "checks every file, not just the first" {
  cat > "${WF}/good.yml" << 'EOF'
concurrency:
  group: g
on: push
jobs:
  build:
    runs-on: ubuntu-latest
EOF
  cat > "${WF}/bad.yml" << 'EOF'
on: push
jobs:
  build:
    runs-on: ubuntu-latest
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
  assert_output --partial 'bad.yml'
}

@test "exits 0 when the workflows dir does not exist" {
  WORKFLOWS_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/nope" run "${CHECK}"
  assert_success
}

@test "dies when given an argument" {
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}
