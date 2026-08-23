setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-workflow-hermetic"
  WF="${BATS_TEST_TMPDIR}/wf"
  ACT_ROOT="${BATS_TEST_TMPDIR}/actions"
  mkdir -p "${WF}" "${ACT_ROOT}/myaction"
  # The shipped EXEMPT list names a step in the real repo, which does not exist
  # in the synthetic fixture trees below — the entry would read as stale in every
  # case here. Set-but-empty clears it; the cases that need an exemption re-set it
  # on the command itself, and the one that pins the shipped default unsets it.
  export EXEMPT_OVERRIDE=''
  # The forbidden spelling is assembled from two words, so the literal never
  # appears anywhere in this file: the lint under test scans the real tree and
  # cannot tell a fixture line from an offender.
  DEVELOP_WORD='develop'
  DIRECT_SPELLING="nix ${DEVELOP_WORD}"
}

# Write a fixture read from stdin, substituting the @@DIRECT@@ sentinel with the
# forbidden spelling at write time. Same device as the @@STDERR@@ sentinel in
# test/ci/check-vacuous-arity-tests.bats.
write_fixture() {
  local -r dest="$1"
  sed "s|@@DIRECT@@|${DIRECT_SPELLING}|g" > "${dest}"
}

# Run with both override seams pointed at the test tmpdirs.
# .ci/check-workflow-hermetic derives its own repo root via
# `git rev-parse --show-toplevel`. common.bash's #248 hardening leaves CWD at
# BATS_TEST_TMPDIR (outside any git repo) by design, so cd into REPO_DIR before
# every invocation.
run_check() {
  cd "${REPO_DIR}" || return 1
  WORKFLOWS_DIR_OVERRIDE="${WF}" ACTIONS_DIR_OVERRIDE="${ACT_ROOT}" run "${CHECK}" "$@"
}

# ---- rule 1: passes ----

@test "passes: a workflow run step that invokes the wrapper" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - name: do
        run: ./.ci/in-devshell ./check-scripts
EOF
  run_check
  assert_success
}

@test "passes: the wrapper named inside a multi-line block" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - name: do
        run: |
          set -Eeuo pipefail
          count="$(./.ci/in-devshell bats --count test/functions)"
          printf '%s\n' "${count}"
EOF
  run_check
  assert_success
}

@test "passes: a composite-action run step that invokes the wrapper" {
  cat > "${ACT_ROOT}/myaction/action.yml" << 'EOF'
runs:
  using: composite
  steps:
    - shell: bash
      run: ./.ci/in-devshell bashcov --root . -- bats test/functions
EOF
  run_check
  assert_success
}

@test "passes: steps with no run: key are ignored" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - uses: actions/checkout@v7
        with:
          dry-run: false
      - uses: ./.github/actions/setup
EOF
  run_check
  assert_success
}

@test "passes: empty workflow and action directories" {
  run_check
  assert_success
}

# ---- rule 1: fails ----

@test "fails: an unwrapped run step, named by its <file>::<id> key" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - id: bare
        name: do
        run: shellcheck ./check-scripts
EOF
  run_check
  assert_failure 1
  assert_output --partial '.github/workflows/a.yml::bare: run step does not invoke .ci/in-devshell'
  assert_output --partial '1 hermetic-boundary violation(s)'
}

@test "fails: an unwrapped composite-action run step" {
  cat > "${ACT_ROOT}/myaction/action.yml" << 'EOF'
runs:
  using: composite
  steps:
    - id: bare
      shell: bash
      run: echo hello
EOF
  run_check
  assert_failure 1
  assert_output --partial '.github/actions/myaction/action.yml::bare'
}

@test "fails: an unwrapped run step with no id names the fix instead of its name" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - name: Run BATS
        run: bats --recursive test/functions
EOF
  run_check
  assert_failure 1
  assert_output --partial "job 'build' step #0 (Run BATS)"
  assert_output --partial 'has no YAML id:; add one'
  assert_output --partial 'EXEMPT keys are <file>::<id>'
}

@test "fails: counts every offender and reports the total" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - id: one
        run: echo one
  other:
    steps:
      - id: two
        run: echo two
EOF
  run_check
  assert_failure 1
  assert_output --partial '2 hermetic-boundary violation(s)'
}

# ---- rule 2 ----

@test "fails: a workflow that enters the devShell directly" {
  write_fixture "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - id: direct
        run: @@DIRECT@@ --command ./check-scripts
EOF
  run_check
  assert_failure 1
  assert_output --partial 'only .ci/in-devshell may enter the devShell'
}

@test "fails: the direct spelling is caught in a comment too, not only in a run block" {
  write_fixture "${WF}/a.yml" << 'EOF'
on: push
# was: @@DIRECT@@ --command ./check-scripts
jobs:
  build:
    steps:
      - name: do
        run: ./.ci/in-devshell ./check-scripts
EOF
  run_check
  assert_failure 1
  assert_output --partial 'only .ci/in-devshell may enter the devShell'
}

@test "passes: in-devshell does not itself match the forbidden spelling" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - name: do
        run: ./.ci/in-devshell nix flake check
EOF
  run_check
  assert_success
}

# ---- exemptions ----

@test "passes: an exempt step may skip the wrapper" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - id: decide
        run: echo 'run=true' >> "${GITHUB_OUTPUT}"
EOF
  EXEMPT_OVERRIDE='.github/workflows/a.yml::decide' run_check
  assert_success
}

@test "the shipped exemption covers the changed-tests decide step" {
  unset EXEMPT_OVERRIDE
  mkdir -p "${ACT_ROOT}/changed-tests"
  cat > "${ACT_ROOT}/changed-tests/action.yml" << 'EOF'
runs:
  using: composite
  steps:
    - id: decide
      shell: bash
      run: ./.ci/decide-changed-tests "${changed}"
EOF
  run_check
  assert_success
}

@test "fails: an exemption naming no run step is stale" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - name: do
        run: ./.ci/in-devshell ./check-scripts
EOF
  EXEMPT_OVERRIDE='.github/workflows/a.yml::ghost' run_check
  assert_failure 1
  assert_output --partial 'stale EXEMPT entry: .github/workflows/a.yml::ghost matches no run step'
}

@test "fails: an exemption naming a step that does invoke the wrapper is stale" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - id: fixed
        run: ./.ci/in-devshell ./check-scripts
EOF
  EXEMPT_OVERRIDE='.github/workflows/a.yml::fixed' run_check
  assert_failure 1
  assert_output --partial 'stale EXEMPT entry: .github/workflows/a.yml::fixed already invokes .ci/in-devshell'
}

@test "fails: an exemption keyed on the wrong file does not cover the step" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - id: bare
        run: echo hello
EOF
  EXEMPT_OVERRIDE='.github/workflows/b.yml::bare' run_check
  assert_failure 1
  assert_output --partial '.github/workflows/a.yml::bare: run step does not invoke'
  assert_output --partial 'stale EXEMPT entry: .github/workflows/b.yml::bare matches no run step'
}

# ---- arity ----

@test "dies when given an argument" {
  run_check extra
  assert_failure 1
  assert_output --partial 'Expected no arguments'
}

@test "--help exits 0" {
  run_check --help
  assert_success
}
