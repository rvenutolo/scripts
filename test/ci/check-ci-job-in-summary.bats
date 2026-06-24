setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-ci-job-in-summary"
  SUMMARY="${BATS_TEST_TMPDIR}/required-checks.md"
  RULESET="${BATS_TEST_TMPDIR}/protect-main.json"
  WF="${BATS_TEST_TMPDIR}/workflows"
  mkdir -p "${WF}"
}

# Build a ruleset whose required contexts are the given args.
write_ruleset() {
  printf '%s\n' "$@" \
    | jq -R . \
    | jq -s '{name:"protect-main", rules:[{type:"required_status_checks", parameters:{required_status_checks: map({context: .})}}]}' \
    > "${RULESET}"
}

# write_workflow <filename> <jobspec...>  where jobspec = "key" or "key:name".
write_workflow() {
  local fn="$1"
  shift
  {
    echo "on: pull_request"
    echo "jobs:"
    local spec key name
    for spec in "$@"; do
      key="${spec%%:*}"
      name="${spec#*:}"
      echo "  ${key}:"
      echo "    runs-on: ubuntu-latest"
      if [[ "${name}" != "${spec}" && -n "${name}" ]]; then
        echo "    name: ${name}"
      fi
      echo "    steps: [{ run: 'true' }]"
    done
  } > "${WF}/${fn}"
}

# write_summary <row...>  where row = "name|category|protects".
write_summary() {
  {
    echo "<!-- required-checks:begin -->"
    echo "| Check | Category | Protects |"
    echo "|-------|----------|----------|"
    local row name cat prot
    for row in "$@"; do
      IFS='|' read -r name cat prot <<< "${row}"
      echo "| \`${name}\` | ${cat} | ${prot} |"
    done
    echo "<!-- required-checks:end -->"
  } > "${SUMMARY}"
}

run_check() {
  SUMMARY_MD_OVERRIDE="${SUMMARY}" RULESET_JSON_OVERRIDE="${RULESET}" WORKFLOWS_DIR_OVERRIDE="${WF}" run "${CHECK}"
}

@test "passes when table, ruleset, and jobs all agree" {
  write_ruleset bats lint
  write_workflow ci.yml bats lint
  write_summary "bats|testing|unit tests" "lint|format|treefmt gate"
  run_check
  assert_success
}

@test "resolves a job context by its name: override, not its key" {
  write_ruleset reviewdog
  write_workflow ci.yml "review:reviewdog"
  write_summary "reviewdog|lint|reviewdog runner"
  run_check
  assert_success
}

@test "fails when a required check matches a job key whose name: differs" {
  write_ruleset review
  write_workflow ci.yml "review:reviewdog"
  write_summary "review|lint|x"
  run_check
  assert_failure
  assert_output --partial 'no matching workflow job: review'
}

@test "fails when a required check is missing from the table" {
  write_ruleset bats lint
  write_workflow ci.yml bats lint
  write_summary "bats|testing|unit tests"
  run_check
  assert_failure
  assert_output --partial 'missing from table: lint'
}

@test "fails when a table row is not a required check" {
  write_ruleset bats
  write_workflow ci.yml bats coverage
  write_summary "bats|testing|x" "coverage|testing|cov"
  run_check
  assert_failure
  assert_output --partial 'not a required check: coverage'
}

@test "fails when a required check has no matching workflow job" {
  write_ruleset bats ghost
  write_workflow ci.yml bats
  write_summary "bats|testing|x" "ghost|misc|y"
  run_check
  assert_failure
  assert_output --partial 'no matching workflow job: ghost'
}

@test "fails when a table row has an empty Category cell" {
  write_ruleset bats
  write_workflow ci.yml bats
  write_summary "bats||unit tests"
  run_check
  assert_failure
  assert_output --partial 'empty Category or Protects: bats'
}

@test "fails when a table row has an empty Protects cell" {
  write_ruleset bats
  write_workflow ci.yml bats
  write_summary "bats|testing|"
  run_check
  assert_failure
  assert_output --partial 'empty Category or Protects: bats'
}

@test "dies when the summary file is missing" {
  write_ruleset bats
  write_workflow ci.yml bats
  run_check
  assert_failure
  assert_output --partial 'does not exist'
}

@test "dies when given an argument" {
  run "${CHECK}" extra
  assert_failure
}

@test "prints help and exits 0 with --help" {
  run "${CHECK}" --help
  assert_success
}
