setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-pull-request-target-absent"
  WF="${BATS_TEST_TMPDIR}/wf"
  mkdir -p "${WF}"
}

@test "passes when no workflow declares pull_request_target" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    runs-on: ubuntu-latest
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_success
}

@test "fails on map-shape pull_request_target trigger" {
  cat > "${WF}/a.yml" << 'EOF'
on:
  pull_request_target:
    types: [opened]
jobs:
  build:
    runs-on: ubuntu-latest
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
  assert_output --partial 'a.yml'
  assert_output --partial 'pull_request_target'
}

@test "fails on sequence-shape pull_request_target trigger" {
  cat > "${WF}/a.yml" << 'EOF'
on: [push, pull_request_target]
jobs:
  build:
    runs-on: ubuntu-latest
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
  assert_output --partial 'pull_request_target'
}

@test "fails on scalar-shape pull_request_target trigger" {
  cat > "${WF}/a.yml" << 'EOF'
on: pull_request_target
jobs:
  build:
    runs-on: ubuntu-latest
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
  assert_output --partial 'pull_request_target'
}

@test "passes when pull_request_target appears only in a comment" {
  cat > "${WF}/a.yml" << 'EOF'
# pull_request_target is intentionally NOT used here
on: push
jobs:
  build:
    runs-on: ubuntu-latest
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_success
}

@test "passes on plain pull_request (not _target)" {
  cat > "${WF}/a.yml" << 'EOF'
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_success
}

@test "checks every file, not just the first" {
  cat > "${WF}/good.yml" << 'EOF'
on: push
jobs:
  build:
    runs-on: ubuntu-latest
EOF
  cat > "${WF}/bad.yml" << 'EOF'
on:
  pull_request_target:
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
