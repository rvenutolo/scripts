# shellcheck disable=SC2016 # fixtures are markdown table rows: the backticks are literal
# README syntax, and the single quotes are deliberate — nothing here should expand.

setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-readme-workflow-table"
  WF="${BATS_TEST_TMPDIR}/wf"
  MD="${BATS_TEST_TMPDIR}/README.md"
  mkdir -p "${WF}"
}

# .ci/check-readme-workflow-table derives its own repo root via
# `git rev-parse --show-toplevel`. common.bash's #248 hardening leaves CWD at
# BATS_TEST_TMPDIR (outside any git repo) by design, so cd into REPO_DIR before
# every invocation.
run_check() {
  cd "${REPO_DIR}" || return 1
  run "$@"
}

# Write a workflow-table fixture. Each argument is one already-formatted row.
write_table() {
  {
    printf 'Some preamble prose.\n\n'
    printf -- '<!-- workflow-table:begin -->\n'
    printf '| Workflow | Trigger | Purpose |\n'
    printf -- '| --- | --- | --- |\n'
    printf '%s\n' "$@"
    printf -- '<!-- workflow-table:end -->\n'
    printf '\nA later table that must be ignored.\n\n'
    printf '| Other | Table |\n| --- | --- |\n| `decoy.yml` | not a workflow row |\n'
  } > "${MD}"
}

run_with() {
  README_OVERRIDE="${MD}" WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
}

@test "passes when the table matches the workflow directory exactly" {
  touch "${WF}/a.yml" "${WF}/b.yml"
  write_table '| `a.yml` | push | Does a thing. |' '| `b.yml` | PR | Does another thing. |'
  run_with
  assert_success
}

@test "fails when a workflow has no table row" {
  touch "${WF}/a.yml" "${WF}/orphan.yml"
  write_table '| `a.yml` | push | Does a thing. |'
  run_with
  assert_failure
  assert_output --partial 'workflow missing from README table: orphan.yml'
}

@test "fails when a table row names no workflow" {
  touch "${WF}/a.yml"
  write_table '| `a.yml` | push | Does a thing. |' '| `ghost.yml` | push | Was deleted. |'
  run_with
  assert_failure
  assert_output --partial 'README table row is not a workflow: ghost.yml'
}

@test "reports a missing row and a stale row in the same run" {
  touch "${WF}/a.yml" "${WF}/orphan.yml"
  write_table '| `a.yml` | push | Does a thing. |' '| `ghost.yml` | push | Was deleted. |'
  run_with
  assert_failure
  assert_output --partial 'workflow missing from README table: orphan.yml'
  assert_output --partial 'README table row is not a workflow: ghost.yml'
}

@test "fails when a row has an empty Trigger cell" {
  touch "${WF}/a.yml"
  write_table '| `a.yml` |  | Does a thing. |'
  run_with
  assert_failure
  assert_output --partial 'a.yml'
  assert_output --partial 'empty Trigger or Purpose'
}

@test "fails when a row has an empty Purpose cell" {
  touch "${WF}/a.yml"
  write_table '| `a.yml` | push |  |'
  run_with
  assert_failure
  assert_output --partial 'a.yml'
  assert_output --partial 'empty Trigger or Purpose'
}

@test "ignores tables outside the begin/end markers" {
  touch "${WF}/a.yml"
  write_table '| `a.yml` | push | Does a thing. |'
  run_with
  assert_success
  refute_output --partial 'decoy.yml'
}

@test "matches .yaml workflows as well as .yml" {
  touch "${WF}/a.yaml"
  write_table '| `a.yaml` | push | Does a thing. |'
  run_with
  assert_success
}

@test "dies when the begin marker is absent" {
  touch "${WF}/a.yml"
  printf '| `a.yml` | push | Does a thing. |\n' > "${MD}"
  run_with
  assert_failure
  assert_output --partial 'workflow-table:begin'
}

@test "dies when the README does not exist" {
  touch "${WF}/a.yml"
  README_OVERRIDE="${BATS_TEST_TMPDIR}/nope.md" WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'nope.md'
}

@test "passes against the real repository README" {
  run_check "${CHECK}"
  assert_success
}

@test "dies with 1 arg" {
  run_check "${CHECK}" 'unexpected'
  assert_failure
  assert_output --partial 'Expected no arguments'
}
