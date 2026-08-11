setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-required-checks-no-paths"
  WF="${BATS_TEST_TMPDIR}/wf"
  mkdir -p "${WF}"
}

# .ci/check-required-checks-no-paths derives its own repo root via `git
# rev-parse --show-toplevel`. common.bash's #248 hardening leaves CWD at
# BATS_TEST_TMPDIR (outside any git repo) by design, so cd into REPO_DIR
# before every invocation — this test targets the real repo.
run_check() {
  cd "${REPO_DIR}" || return 1
  run "$@"
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
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
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
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
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
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
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
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_success
}

@test "dies when given an argument" {
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}
