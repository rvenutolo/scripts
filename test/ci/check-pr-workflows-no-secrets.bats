setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-pr-workflows-no-secrets"
  WF="${BATS_TEST_TMPDIR}/wf"
  mkdir -p "${WF}"
}

@test "passes: PR workflow using only GITHUB_TOKEN" {
  cat > "${WF}/a.yml" << 'EOF'
on:
  pull_request:
    branches: [main]
jobs:
  x:
    steps:
      - env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_success
}

@test "fails: PR workflow referencing a non-GITHUB_TOKEN secret" {
  cat > "${WF}/a.yml" << 'EOF'
on:
  pull_request:
    branches: [main]
jobs:
  x:
    steps:
      - env:
          TOK: ${{ secrets.RULESET_READ_TOKEN }}
        run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
  assert_output --partial 'secrets.RULESET_READ_TOKEN'
}

@test "ignores non-PR workflows entirely" {
  cat > "${WF}/a.yml" << 'EOF'
on:
  push:
    branches: [main]
jobs:
  x:
    steps:
      - env:
          TOK: ${{ secrets.RULESET_READ_TOKEN }}
        run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_success
}

@test "detects pull_request_target" {
  cat > "${WF}/a.yml" << 'EOF'
on:
  pull_request_target:
    branches: [main]
jobs:
  x:
    steps:
      - env:
          TOK: ${{ secrets.OTHER }}
        run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
}

@test "detects flow-list on: [push, pull_request]" {
  cat > "${WF}/a.yml" << 'EOF'
on: [push, pull_request]
jobs:
  x:
    steps:
      - env:
          TOK: ${{ secrets.OTHER }}
        run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
  assert_failure
}

@test "dies when given an argument" {
  WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}
