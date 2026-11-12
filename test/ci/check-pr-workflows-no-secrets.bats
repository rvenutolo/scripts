setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-pr-workflows-no-secrets"
  WF="${BATS_TEST_TMPDIR}/wf"
  mkdir -p "${WF}"
}

# .ci/check-pr-workflows-no-secrets derives its own repo root via `git
# rev-parse --show-toplevel`. common.bash's fixture-escape hardening leaves CWD
# at BATS_TEST_TMPDIR (outside any git repo) by design, so cd into REPO_DIR
# before every invocation — this test targets the real repo.
run_check() {
  cd "${REPO_DIR}" || return 1
  run "$@"
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
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
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
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
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
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
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
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
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
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
}

@test "dies when given an argument" {
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "fails loudly on a workflow yq cannot parse" {
  # The trigger enumeration must stay a plain command. As a predicate called from
  # an `if` it disables errexit for its whole call tree: a failing yq then reads
  # as "not triggered", the file goes unscanned, and the check exits 0.
  printf -- '- a\n- b\n' > "${WF}/seq.yml"
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure 1
}

# A missing scan target must not read as a clean pass. An absent directory is
# indistinguishable from a directory whose contents are all fine, and this gate is
# what stands between the repo and the thing it checks — the silent-false-green
# shape this repo spends the most effort on. An `exit 0` here when
# WORKFLOWS_DIR is absent would disarm the check while every run stayed green.
@test "dies when the workflows directory is absent" {
  WORKFLOWS_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/absent" run_check "${CHECK}"
  assert_failure 1
  assert_output --partial 'does not exist'
}

# write_pr_workflow <step-line...>: a pull_request workflow whose single job
# carries the given lines verbatim, indented under `steps:`.
write_pr_workflow() {
  {
    printf 'on:\n  pull_request:\njobs:\n  x:\n    runs-on: ubuntu-latest\n    steps:\n'
    local line
    for line in "$@"; do
      printf '      %s\n' "${line}"
    done
  } > "${WF}/a.yml"
}

@test "fails: single-quoted bracket-form secret reference" {
  write_pr_workflow "- env:" "    TOK: \${{ secrets['BR_TOKEN'] }}" "  run: true"
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure 1
  assert_output --partial 'secrets.BR_TOKEN not allowed'
}

@test "fails: double-quoted bracket-form secret reference" {
  write_pr_workflow "- env:" "    TOK: '\${{ secrets[\"BR_TOKEN\"] }}'" "  run: true"
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure 1
  assert_output --partial 'secrets.BR_TOKEN not allowed'
}

@test "fails: bracket-form secret reference with whitespace inside the brackets" {
  write_pr_workflow "- env:" "    TOK: \${{ secrets[ 'WS_TOKEN' ] }}" "  run: true"
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure 1
  assert_output --partial 'secrets.WS_TOKEN not allowed'
}

@test "fails: lower-case secret reference" {
  write_pr_workflow "- env:" "    TOK: \${{ secrets.ruleset_read_token }}" "  run: true"
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure 1
  assert_output --partial 'secrets.RULESET_READ_TOKEN not allowed'
}

@test "passes: lower-case GITHUB_TOKEN reference" {
  write_pr_workflow "- env:" "    TOK: \${{ secrets.github_token }}" "  run: true"
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_success
}

@test "fails: whole secrets context passed to toJSON" {
  write_pr_workflow "- env:" "    ALL: \${{ toJSON(secrets) }}" "  run: true"
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure 1
  assert_output --partial 'toJSON(secrets)'
}

@test "fails: dynamically indexed secret reference" {
  write_pr_workflow "- env:" "    TOK: \${{ secrets[format('{0}_TOKEN', 'X')] }}" "  run: true"
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure 1
  assert_output --partial 'secrets[format('
}

@test "fails: secrets inherited by a called workflow" {
  printf 'on:\n  pull_request:\njobs:\n  call:\n    uses: ./.github/workflows/b.yml\n    secrets: inherit\n' > "${WF}/a.yml"
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure 1
  assert_output --partial 'secrets: inherit'
}

@test "fails: secret referenced in a shell comment inside a run block" {
  write_pr_workflow "- run: |" "    # \${{ secrets.SH_TOKEN }}" "    true"
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure 1
  assert_output --partial 'secrets.SH_TOKEN not allowed'
}

@test "passes: secret named only in a YAML comment line" {
  write_pr_workflow "# was \${{ secrets.GONE_TOKEN }}" "- run: true"
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_success
}

@test "passes: identifier that merely ends in secrets" {
  write_pr_workflow "- env:" "    TOK: \${{ mysecrets.NOT_A_SECRET }}" "  run: true"
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_success
}

@test "reports the line of each violation" {
  write_pr_workflow "- env:" "    TOK: \${{ secrets.FOO_TOKEN }}" "  run: true"
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure 1
  assert_output --partial 'a.yml:8: secrets.FOO_TOKEN not allowed'
}
