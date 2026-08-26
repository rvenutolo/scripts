setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-harden-runner-first"
  WF="${BATS_TEST_TMPDIR}/wf"
  mkdir -p "${WF}"
  HR='step-security/harden-runner@ab7a9404c0f3da075243ca237b5fac12c98deaa5'
}

# .ci/check-harden-runner-first derives its own repo root via
# `git rev-parse --show-toplevel`. common.bash's #248 hardening leaves CWD at
# BATS_TEST_TMPDIR (outside any git repo) by design, so cd into REPO_DIR before
# every invocation — this test targets the real repo.
run_check() {
  cd "${REPO_DIR}" || return 1
  run "$@"
}

@test "passes when harden-runner is the SHA-pinned first step" {
  cat > "${WF}/a.yml" << EOF
jobs:
  build:
    steps:
      - uses: ${HR}
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_success
}

@test "fails when first step is not harden-runner" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'first step'
}

@test "fails when first step has no uses (run step)" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    steps:
      - run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'no first-step'
}

@test "fails when harden-runner ref is not SHA-pinned" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    steps:
      - uses: step-security/harden-runner@v2
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'not SHA-pinned'
}

@test "checks every job, not just the first" {
  cat > "${WF}/a.yml" << EOF
jobs:
  good:
    steps:
      - uses: ${HR}
  bad:
    steps:
      - run: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
}

@test "dies when given an argument" {
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "fails loudly on a workflow yq cannot parse" {
  # Regression for #290. The per-file helper runs inside a command substitution,
  # where bash unsets errexit unless inherit_errexit is set. A failing yq used to
  # leave the helper running past it, echoing a zero count, so the check exited 0
  # with the unparsable file never scanned.
  printf -- '- a\n- b\n' > "${WF}/seq.yml"
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure 1
}

# A missing scan target must not read as a clean pass. An absent directory is
# indistinguishable from a directory whose contents are all fine, and this gate is
# what stands between the repo and the thing it checks — the silent-false-green
# shape of #250, #290 and #307, and the rule CLAUDE.md states as "Empty scan
# results are failures, not clean passes". Surfaced the `exit 0` guard this check
# used to carry when WORKFLOWS_DIR was absent (#323).
@test "dies when the workflows directory is absent" {
  WORKFLOWS_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/absent" run_check "${CHECK}"
  assert_failure 1
  assert_output --partial 'does not exist'
}
