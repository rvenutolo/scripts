setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-min-permissions"
  WF="${BATS_TEST_TMPDIR}/wf"
  mkdir -p "${WF}"
}

# .ci/check-min-permissions derives its own repo root via `git rev-parse
# --show-toplevel`. common.bash's fixture-escape hardening leaves CWD at
# BATS_TEST_TMPDIR (outside any git repo) by design, so cd into REPO_DIR before
# every invocation — this test targets the real repo.
run_check() {
  cd "${REPO_DIR}" || return 1
  run "$@"
}

@test "passes: empty top-level + per-job blocks" {
  cat > "${WF}/a.yml" << 'EOF'
permissions: {}
jobs:
  build:
    permissions:
      contents: read
    steps:
      - run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_success
}

@test "fails: missing top-level permissions" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    permissions:
      contents: read
    steps:
      - run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'missing top-level'
}

@test "fails: non-empty top-level permissions" {
  cat > "${WF}/a.yml" << 'EOF'
permissions:
  contents: read
jobs:
  build:
    permissions:
      contents: read
    steps:
      - run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'non-empty'
}

@test "fails: scalar top-level permissions" {
  cat > "${WF}/a.yml" << 'EOF'
permissions: read-all
jobs:
  build:
    permissions:
      contents: read
    steps:
      - run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
}

@test "fails: a job missing its permissions block" {
  cat > "${WF}/a.yml" << 'EOF'
permissions: {}
jobs:
  build:
    steps:
      - run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'missing'
}

@test "dies when given an argument" {
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}

# A missing scan target must not read as a clean pass. An absent directory is
# indistinguishable from a directory whose contents are all fine, and this gate is
# what stands between the repo and the thing it checks — the silent-false-green
# shape this repo spends the most effort on, and the rule CLAUDE.md states as
# "Empty scan results are failures, not clean passes". An `exit 0` here when
# WORKFLOWS_DIR is absent would disarm the check while every run stayed green.
@test "dies when the workflows directory is absent" {
  WORKFLOWS_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/absent" run_check "${CHECK}"
  assert_failure 1
  assert_output --partial 'does not exist'
}

# The two arms of the tag case are not interchangeable: a missing block and a
# malformed one are different mistakes, and only the malformed arm can report the tag
# that explains what was actually written. `permissions: read-all` is the realistic
# way to hit it — valid GitHub Actions syntax, and exactly the over-broad grant this
# gate exists to stop.
@test "fails when a job's permissions block is a scalar rather than a map" {
  cat > "${WF}/a.yml" << 'YAML'
permissions: {}
jobs:
  build:
    runs-on: ubuntu-latest
    permissions: read-all
YAML
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'permissions wrong shape'
  assert_output --partial '!!str'
}
