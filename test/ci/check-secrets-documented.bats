setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-secrets-documented"
  RUNBOOK="${BATS_TEST_TMPDIR}/secrets.md"
  WF="${BATS_TEST_TMPDIR}/workflows"
  ACTIONS="${BATS_TEST_TMPDIR}/actions"
  mkdir -p "${WF}" "${ACTIONS}"
}

# write_runbook <name...>: a runbook with one `## NAME` section per argument.
write_runbook() {
  {
    printf '# Secrets\n\nIntro.\n'
    local name
    for name in "$@"; do
      printf '\n## %s\n\n- **Used by:** something.\n' "${name}"
    done
  } > "${RUNBOOK}"
}

# write_workflow <file> <env-line...>: a minimal workflow whose single step
# carries the given lines verbatim under `env:`.
write_workflow() {
  local -r file="$1"
  shift
  {
    printf 'on: push\njobs:\n  job:\n    runs-on: ubuntu-latest\n    steps:\n      - run: "true"\n        env:\n'
    local line
    for line in "$@"; do
      printf '          %s\n' "${line}"
    done
  } > "${file}"
}

# secret_ref <name>: the expression text for a dot-form secret reference, built
# at runtime so this file holds no literal reference.
secret_ref() {
  printf '%s{{ secrets.%s }}' '$' "$1"
}

# .ci/check-secrets-documented derives its repo root via `git rev-parse
# --show-toplevel`, and common.bash leaves CWD outside any repo, so cd first.
# run_check_with <runbook> <workflows-dir> <actions-dir> [<arg>...]
run_check_with() {
  local -r runbook="$1" workflows="$2" actions="$3"
  shift 3
  cd "${REPO_DIR}" || return 1
  SECRETS_MD_OVERRIDE="${runbook}" WORKFLOWS_DIR_OVERRIDE="${workflows}" ACTIONS_DIR_OVERRIDE="${actions}" \
    run --separate-stderr "${CHECK}" "$@"
}

run_check() {
  run_check_with "${RUNBOOK}" "${WF}" "${ACTIONS}" "$@"
}

@test "passes when every used secret is documented and vice versa" {
  write_workflow "${WF}/a.yml" "A: $(secret_ref FOO_TOKEN)"
  write_runbook FOO_TOKEN
  run_check
  assert_success
}

@test "fails on an undocumented secret" {
  write_workflow "${WF}/a.yml" "A: $(secret_ref FOO_TOKEN)" "B: $(secret_ref BAR_TOKEN)"
  write_runbook FOO_TOKEN
  run_check
  assert_failure 1
  assert_stderr --partial 'undocumented secret: BAR_TOKEN'
  refute_stderr --partial 'FOO_TOKEN'
}

@test "fails on a stale runbook entry" {
  write_workflow "${WF}/a.yml" "A: $(secret_ref FOO_TOKEN)"
  write_runbook FOO_TOKEN OLD_TOKEN
  run_check
  assert_failure 1
  assert_stderr --partial 'stale secret entry: OLD_TOKEN'
}

@test "ignores GITHUB_TOKEN" {
  write_workflow "${WF}/a.yml" "A: $(secret_ref GITHUB_TOKEN)" "B: $(secret_ref FOO_TOKEN)"
  write_runbook FOO_TOKEN
  run_check
  assert_success
}

@test "reads .yaml workflow files" {
  write_workflow "${WF}/a.yaml" "A: $(secret_ref FOO_TOKEN)"
  write_runbook
  printf '\n## OTHER_TOKEN\n' >> "${RUNBOOK}"
  run_check
  assert_failure 1
  assert_stderr --partial 'undocumented secret: FOO_TOKEN'
}

@test "counts secrets referenced from a composite action" {
  write_workflow "${WF}/a.yml" "A: $(secret_ref FOO_TOKEN)"
  mkdir -p "${ACTIONS}/x"
  write_workflow "${ACTIONS}/x/action.yml" "A: $(secret_ref ACT_TOKEN)"
  write_runbook FOO_TOKEN
  run_check
  assert_failure 1
  assert_stderr --partial 'undocumented secret: ACT_TOKEN'
}

@test "ignores secret references in YAML comment lines" {
  write_workflow "${WF}/a.yml" "A: $(secret_ref FOO_TOKEN)" "# was $(secret_ref GONE_TOKEN)"
  write_runbook FOO_TOKEN
  run_check
  assert_success
}

@test "counts single-quoted bracket-form secret references" {
  write_workflow "${WF}/a.yml" "A: $(secret_ref FOO_TOKEN)" "B: \${{ secrets['BR_TOKEN'] }}"
  write_runbook FOO_TOKEN
  run_check
  assert_failure 1
  assert_stderr --partial 'undocumented secret: BR_TOKEN'
}

@test "counts double-quoted bracket-form secret references" {
  write_workflow "${WF}/a.yml" "A: $(secret_ref FOO_TOKEN)" "B: '\${{ secrets[\"BR_TOKEN\"] }}'"
  write_runbook FOO_TOKEN
  run_check
  assert_failure 1
  assert_stderr --partial 'undocumented secret: BR_TOKEN'
}

@test "counts every secret on a line that references several" {
  write_workflow "${WF}/a.yml" "A: $(secret_ref FOO_TOKEN)-$(secret_ref BAR_TOKEN)"
  write_runbook FOO_TOKEN
  run_check
  assert_failure 1
  assert_stderr --partial 'undocumented secret: BAR_TOKEN'
}

@test "ignores headings that are not secret names" {
  write_workflow "${WF}/a.yml" "A: $(secret_ref FOO_TOKEN)"
  write_runbook FOO_TOKEN
  printf '\n## Adding a secret\n\n### SUB_TOKEN\n' >> "${RUNBOOK}"
  run_check
  assert_success
}

@test "reports an undocumented secret once however many times it is used" {
  write_workflow "${WF}/a.yml" "A: $(secret_ref FOO_TOKEN)" "B: $(secret_ref BAR_TOKEN)" "C: $(secret_ref BAR_TOKEN)"
  write_workflow "${WF}/b.yml" "D: $(secret_ref BAR_TOKEN)"
  write_runbook FOO_TOKEN
  run_check
  assert_failure 1
  local count
  count="$(grep --count 'undocumented secret: BAR_TOKEN' <<< "${stderr}")"
  [[ "${count}" -eq 1 ]]
}

@test "fails when no workflow reads any secret" {
  write_workflow "${WF}/a.yml" "A: $(secret_ref GITHUB_TOKEN)"
  write_runbook FOO_TOKEN
  run_check
  assert_failure 1
  assert_stderr --partial 'no secret references found'
}

@test "fails when the runbook has no secret sections" {
  write_workflow "${WF}/a.yml" "A: $(secret_ref FOO_TOKEN)"
  write_runbook
  run_check
  assert_failure 1
  assert_stderr --partial 'no secret sections found'
}

@test "fails when the runbook is missing" {
  write_workflow "${WF}/a.yml" "A: $(secret_ref FOO_TOKEN)"
  run_check_with "${BATS_TEST_TMPDIR}/absent.md" "${WF}" "${ACTIONS}"
  assert_failure 1
  assert_stderr --partial 'absent.md'
}

@test "fails when the workflows directory is missing" {
  write_runbook FOO_TOKEN
  run_check_with "${RUNBOOK}" "${BATS_TEST_TMPDIR}/no-workflows" "${ACTIONS}"
  assert_failure 1
  assert_stderr --partial 'no-workflows'
}

@test "fails when the actions directory is missing" {
  write_workflow "${WF}/a.yml" "A: $(secret_ref FOO_TOKEN)"
  write_runbook FOO_TOKEN
  run_check_with "${RUNBOOK}" "${WF}" "${BATS_TEST_TMPDIR}/no-actions"
  assert_failure 1
  assert_stderr --partial 'no-actions'
}

@test "rejects arguments" {
  write_workflow "${WF}/a.yml" "A: $(secret_ref FOO_TOKEN)"
  write_runbook FOO_TOKEN
  run_check extra
  assert_failure 1
  assert_stderr --partial 'Expected no arguments'
}

@test "passes against the real repository" {
  cd "${REPO_DIR}" || return 1
  run --separate-stderr "${CHECK}"
  assert_success
}
