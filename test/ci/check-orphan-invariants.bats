setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-orphan-invariants"
  INDEX="${BATS_TEST_TMPDIR}/invariant-index.md"
  RULESET="${BATS_TEST_TMPDIR}/protect-main.json"
  WF="${BATS_TEST_TMPDIR}/workflows"
  CI="${BATS_TEST_TMPDIR}/ci"
  RUNNER="${BATS_TEST_TMPDIR}/run-governance-checks"
  mkdir -p "${WF}" "${CI}"
  export INDEX_MD_OVERRIDE="${INDEX}"
  export RULESET_JSON_OVERRIDE="${RULESET}"
  export WORKFLOWS_DIR_OVERRIDE="${WF}"
  export CI_DIR_OVERRIDE="${CI}"
  export GOVERNANCE_RUNNER_OVERRIDE="${RUNNER}"
}

# write_ruleset <context...> — ruleset whose required contexts are the args.
write_ruleset() {
  printf '%s\n' "$@" \
    | jq -R . \
    | jq -s '{name:"protect-main", rules:[{type:"required_status_checks", parameters:{required_status_checks: map({context: .})}}]}' \
    > "${RULESET}"
}

# write_workflow <filename> <jobkey...> — each job key becomes a job context.
write_workflow() {
  local fn="$1"
  shift
  {
    echo "on: pull_request"
    echo "jobs:"
    local key
    for key in "$@"; do
      echo "  ${key}:"
      echo "    runs-on: ubuntu-latest"
      echo "    steps: [{ run: 'true' }]"
    done
  } > "${WF}/${fn}"
}

# write_index <row...> — row = "invariant|enforcer|cijob|required".
write_index() {
  {
    echo "<!-- invariant-index:begin -->"
    echo "| Invariant | Enforcer | CI job | Required check |"
    echo "|-----------|----------|--------|----------------|"
    local row inv enf job req
    for row in "$@"; do
      IFS='|' read -r inv enf job req <<< "${row}"
      echo "| ${inv} | \`${enf}\` | ${job} | ${req} |"
    done
    echo "<!-- invariant-index:end -->"
  } > "${INDEX}"
}

# make_ci <name...> — create an executable stub .ci script per name.
make_ci() {
  local name
  for name in "$@"; do
    printf '#!/usr/bin/env bash\ntrue\n' > "${CI}/${name}"
    chmod +x "${CI}/${name}"
  done
}

# write_runner <name...> — a run-governance-checks-shaped file listing names.
write_runner() {
  {
    echo '#!/usr/bin/env bash'
    echo '  for check in \'
    local name
    for name in "$@"; do
      echo "    ${name} \\"
    done
    echo '    ; do'
    echo '    "${ci}/${check}"'
    echo '  done'
  } > "${RUNNER}"
}

# A self-consistent baseline: one governance enforcer + one check-scripts one.
baseline() {
  make_ci check-foo check-bar
  write_runner check-foo
  write_workflow ci.yml governance check-scripts
  write_ruleset governance check-scripts
  write_index \
    "foo invariant|check-foo|governance|governance" \
    "bar invariant|check-bar|check-scripts|check-scripts"
}

@test "passes on a self-consistent fixture" {
  baseline
  run "${CHECK}"
  [ "${status}" -eq 0 ]
  [ -z "${output}" ]
}

@test "fails on an orphan enforcer (ci script with no index row)" {
  baseline
  make_ci check-orphan
  run "${CHECK}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"check-orphan"* ]]
}

@test "fails when an Enforcer cell does not resolve to a .ci executable" {
  baseline
  write_index \
    "foo invariant|check-foo|governance|governance" \
    "bar invariant|check-bar|check-scripts|check-scripts" \
    "ghost invariant|check-ghost|governance|governance"
  write_runner check-foo check-ghost
  run "${CHECK}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"check-ghost"* ]]
}

@test "fails when a CI job cell does not resolve to a workflow job" {
  baseline
  write_index \
    "foo invariant|check-foo|governance|governance" \
    "bar invariant|check-bar|nonexistent-job|check-scripts"
  run "${CHECK}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"nonexistent-job"* ]]
}

@test "fails when a Required check cell does not resolve to a ruleset context" {
  baseline
  write_index \
    "foo invariant|check-foo|governance|governance" \
    "bar invariant|check-bar|check-scripts|not-required"
  run "${CHECK}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"not-required"* ]]
}

@test "passes when a Required check cell is blank" {
  make_ci check-foo
  write_runner check-foo
  write_workflow ci.yml governance
  write_ruleset governance
  write_index "foo invariant|check-foo|governance|governance"
  # add a non-required row whose required cell is empty
  make_ci check-baz
  write_workflow extra.yml baz-job
  write_index \
    "foo invariant|check-foo|governance|governance" \
    "baz invariant|check-baz|baz-job|"
  run "${CHECK}"
  [ "${status}" -eq 0 ]
}

@test "fails on an empty Invariant cell" {
  make_ci check-foo
  write_runner check-foo
  write_workflow ci.yml governance
  write_ruleset governance
  write_index "|check-foo|governance|governance"
  run "${CHECK}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"empty"* ]]
}

@test "fails on an empty Enforcer cell" {
  make_ci check-foo
  write_runner check-foo
  write_workflow ci.yml governance
  write_ruleset governance
  write_index \
    "foo invariant|check-foo|governance|governance" \
    "bad invariant||governance|governance"
  run "${CHECK}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"empty"* ]]
  [[ "${output}" == *"Enforcer"* ]]
}

@test "fails on an empty CI job cell" {
  make_ci check-foo check-bar
  write_runner check-foo
  write_workflow ci.yml governance check-scripts
  write_ruleset governance check-scripts
  write_index \
    "foo invariant|check-foo|governance|governance" \
    "bar invariant|check-bar||check-scripts"
  run "${CHECK}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"empty"* ]]
  [[ "${output}" == *"CI job"* ]]
}

@test "fails when a governance-job row's enforcer is not in the runner" {
  baseline
  write_runner   # empty runner
  run "${CHECK}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"check-foo"* ]]
}

@test "fails when a runner entry has no governance-job row" {
  baseline
  write_runner check-foo check-bar   # check-bar is a check-scripts row
  run "${CHECK}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"check-bar"* ]]
}

@test "dies when the index file is missing" {
  baseline
  rm -f "${INDEX}"
  run "${CHECK}"
  [ "${status}" -ne 0 ]
}

@test "prints help and exits 0 with --help" {
  run "${CHECK}" --help
  [ "${status}" -eq 0 ]
}

@test "dies when given an argument" {
  run "${CHECK}" bogus
  [ "${status}" -ne 0 ]
}
