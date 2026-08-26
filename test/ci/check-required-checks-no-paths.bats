setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-required-checks-no-paths"
  WF="${BATS_TEST_TMPDIR}/wf"
  mkdir -p "${WF}"
}

# .ci/check-required-checks-no-paths derives its own repo root via `git
# rev-parse --show-toplevel`. common.bash's fixture-escape hardening leaves CWD
# at BATS_TEST_TMPDIR (outside any git repo) by design, so cd into REPO_DIR
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

@test "fails loudly on a workflow yq cannot parse" {
  # A `2> /dev/null || printf 'false'` fallback on the yq call would report an
  # unreadable document as "declares no path filter", and the check would exit 0
  # having never inspected it.
  printf -- '- a\n- b\n' > "${WF}/seq.yml"
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure 1
}

@test "passes on a flow-list on: trigger" {
  # The shape that tempts a fallback: `.on.pull_request` errors while indexing a
  # sequence, before any select on the result can filter it. Guarding `.on` itself
  # is what makes the fallback unnecessary.
  cat > "${WF}/a.yml" << 'EOF2'
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
EOF2
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_success
}

@test "passes on a scalar on: trigger" {
  cat > "${WF}/a.yml" << 'EOF2'
on: push
jobs:
  build:
    runs-on: ubuntu-latest
EOF2
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_success
}

@test "still fails on paths-ignore, not only paths" {
  cat > "${WF}/a.yml" << 'EOF2'
on:
  pull_request:
    paths-ignore:
      - '**.md'
EOF2
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'declares paths/paths-ignore under on.pull_request'
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
