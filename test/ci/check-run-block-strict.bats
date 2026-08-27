setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-run-block-strict"
  WF="${BATS_TEST_TMPDIR}/wf"
  ACT_ROOT="${BATS_TEST_TMPDIR}/actions"
  mkdir -p "${WF}" "${ACT_ROOT}/myaction"
}

# Run with both override seams pointed at the test tmpdirs.
# .ci/check-run-block-strict derives its own repo root via `git rev-parse
# --show-toplevel`. common.bash's fixture-escape hardening leaves CWD at
# BATS_TEST_TMPDIR (outside any git repo) by design, so cd into REPO_DIR before
# every invocation — this test targets the real repo.
run_check() {
  cd "${REPO_DIR}" || return 1
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

@test "passes: .ci/in-devshell wrapper, single physical line" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - run: |
          # a comment
          ./.ci/in-devshell ./.ci/run-governance-checks
EOF
  run_check
  assert_success
}

@test "passes: .ci/in-devshell spelled without the leading ./" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - run: |
          # a comment
          .ci/in-devshell ./.ci/run-governance-checks
EOF
  run_check
  assert_success
}

@test "passes: .ci/in-devshell bash -c with backslash continuation" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - run: |
          ./.ci/in-devshell bash -c \
            'set -Eeuo pipefail; echo hi'
EOF
  run_check
  assert_success
}

@test "passes: .ci/in-devshell bash -c with multi-line quoted inner script" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - run: |
          ./.ci/in-devshell bash -c '
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

@test "fails: a bare nix develop block still needs the strict-mode prelude" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - run: |
          nix develop --command ./.ci/run-governance-checks
          echo after
EOF
  run_check
  assert_failure
  assert_output --partial 'missing strict-mode prelude'
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
  assert_failure 1
  assert_output --partial 'Expected no arguments'
}

# The `*)` arm of the token scan swallows anything that is neither `pipefail` nor a
# `-flag`. A trailing bare word is the shape that reaches it, and the prelude must
# still be judged strict on the flags that are present rather than rejected for the
# stray token.
@test "a set line with a trailing bare word is still recognised as strict" {
  cat > "${WF}/a.yml" << 'YAML'
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - id: s
        run: |
          set -Eeuo pipefail extra
          printf 'hi\n'
YAML
  run_check
  assert_success
}
