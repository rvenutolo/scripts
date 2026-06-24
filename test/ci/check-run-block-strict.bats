setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-run-block-strict"
  WF="${BATS_TEST_TMPDIR}/wf"
  ACT_ROOT="${BATS_TEST_TMPDIR}/actions"
  mkdir -p "${WF}" "${ACT_ROOT}/myaction"
}

# Run with both override seams pointed at the test tmpdirs.
run_check() {
  WORKFLOWS_DIR_OVERRIDE="${WF}" ACTIONS_DIR_OVERRIDE="${ACT_ROOT}" run "${CHECK}" "$@"
}

# ---- passes ----

@test "passes: multi-line bash block with set -Eeuo pipefail first" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - name: do
        run: |
          set -Eeuo pipefail
          echo one
          echo two
EOF
  run_check
  assert_success
}

@test "passes: single-line run block (flow scalar)" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - run: echo hello
EOF
  run_check
  assert_success
}

@test "passes: block reducing to one meaningful line (comment + one command)" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - run: |
          # just one real command
          echo hello
EOF
  run_check
  assert_success
}

@test "passes: nix develop --command wrapper, single physical line" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - run: |
          # a comment
          nix develop --command ./.ci/run-governance-checks
EOF
  run_check
  assert_success
}

@test "passes: nix develop --command bash -c with backslash continuation" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - run: |
          nix develop --command bash -c \
            'set -Eeuo pipefail; echo hi'
EOF
  run_check
  assert_success
}

@test "passes: nix develop --command bash -c with multi-line quoted inner script" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - run: |
          nix develop --command bash -c '
            set -Eeuo pipefail
            echo one
            echo two
          '
EOF
  run_check
  assert_success
}

@test "passes: non-bash shell is exempt even with a bad block" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - shell: python
        run: |
          import os
          print(os.getcwd())
EOF
  run_check
  assert_success
}

@test "passes: shell sh is exempt (bash prelude invalid there)" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - shell: sh
        run: |
          echo one
          echo two
EOF
  run_check
  assert_success
}

@test "passes: prelude with separated flags set -e -E -u -o pipefail" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - run: |
          set -e -E -u -o pipefail
          echo one
          echo two
EOF
  run_check
  assert_success
}

@test "passes: prelude with reordered cluster set -eEuo pipefail" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - run: |
          set -eEuo pipefail
          echo one
          echo two
EOF
  run_check
  assert_success
}

@test "passes: shell bash explicit with correct prelude" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - shell: bash
        run: |
          set -Eeuo pipefail
          echo one
          echo two
EOF
  run_check
  assert_success
}

# ---- failures ----

@test "fails: two-statement block with no prelude" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - run: |
          echo one
          echo two
EOF
  run_check
  assert_failure
  assert_output --partial 'missing strict-mode prelude'
}

@test "fails: set -euo pipefail is missing -E" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - run: |
          set -euo pipefail
          echo one
          echo two
EOF
  run_check
  assert_failure
}

@test "fails: set -eo pipefail is missing -u" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - run: |
          set -eo pipefail
          echo one
          echo two
EOF
  run_check
  assert_failure
}

@test "fails: prelude present but not first meaningful line" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - run: |
          echo before
          set -Eeuo pipefail
          echo after
EOF
  run_check
  assert_failure
}

@test "fails: composite action run step lacks prelude" {
  cat > "${ACT_ROOT}/myaction/action.yml" << 'EOF'
runs:
  using: composite
  steps:
    - shell: bash
      run: |
        echo one
        echo two
EOF
  run_check
  assert_failure
}

@test "fails: counts multiple offenders and reports total" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - run: |
          echo one
          echo two
  other:
    steps:
      - run: |
          echo three
          echo four
EOF
  run_check
  assert_failure
  assert_output --partial '2 run block(s)'
}

# ---- arity ----

@test "dies when given an argument" {
  run_check extra
  assert_failure
}
