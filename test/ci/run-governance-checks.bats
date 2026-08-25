setup() {
  load '../test_helper/common'
  AGG="${REPO_DIR}/.ci/run-governance-checks"
  CI="${BATS_TEST_TMPDIR}/ci"
  RAN="${BATS_TEST_TMPDIR}/ran.log"
  mkdir --parents "${CI}"
}

# .ci/run-governance-checks (an aggregator) derives its own repo root via
# `git rev-parse --show-toplevel`, as do the sub-checks it shells out to.
# common.bash's #248 hardening leaves CWD at BATS_TEST_TMPDIR (outside any git
# repo) by design, so cd into REPO_DIR before every invocation — this test
# targets the real repo.
run_check() {
  cd "${REPO_DIR}" || return 1
  run "$@"
}

# write_stub <name> <exit_code> — a fixture sub-check that records the fact it
# ran (to ${RAN}) and then exits with the given code. Recording the execution
# rather than the exit code is what lets a test prove the runner AGGREGATES:
# a failing check must not stop the ones behind it.
write_stub() {
  local -r name="$1"
  local -r code="$2"
  cat > "${CI}/${name}" << EOF
#!/usr/bin/env bash
printf '%s\n' '${name}' >> '${RAN}'
exit ${code}
EOF
  chmod +x "${CI}/${name}"
}

# stub_all_ci_checks — drop a passing stub for every executable in the real
# .ci/, which is a superset of the runner's hardcoded roster. Deriving the set
# from the directory rather than parsing the roster out of the runner keeps
# this test from re-implementing the runner's own list; roster/​directory parity
# is check-orphan-invariants' job, not this file's.
stub_all_ci_checks() {
  local f name
  for f in "${REPO_DIR}"/.ci/*; do
    [[ -x "${f}" ]] || continue
    name="$(basename "${f}")"
    write_stub "${name}" 0
  done
}

# ran_count — how many fixture sub-checks actually executed.
ran_count() {
  if [[ -f "${RAN}" ]]; then
    wc --lines < "${RAN}"
  else
    printf '0\n'
  fi
}

# announced_count — how many checks the runner said it was running. Every
# announced check must actually execute; a gap between the two means the runner
# aborted partway through.
announced_count() {
  grep --count 'running ' <<< "${output}" || true
}

@test "runs clean against the real repo" {
  run_check "${AGG}"
  assert_success
}

@test "dies when given an argument" {
  run_check "${AGG}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "--help exits 0 and prints help text" {
  run_check "${AGG}" --help
  assert_success
  assert_output --partial 'governance'
}

@test "exits 0 and runs every roster entry when all checks pass" {
  stub_all_ci_checks
  GOVERNANCE_CI_DIR_OVERRIDE="${CI}" run_check "${AGG}"
  assert_success
  [ "$(ran_count)" -eq "$(announced_count)" ]
  [ "$(ran_count)" -ge 30 ]
}

@test "exits 1 when a check fails but still runs the rest" {
  stub_all_ci_checks
  # check-uses-sha-pinned is the FIRST entry in the roster, so a fail-fast
  # runner would stop here and execute nothing else.
  write_stub 'check-uses-sha-pinned' 1
  GOVERNANCE_CI_DIR_OVERRIDE="${CI}" run_check "${AGG}"
  assert_failure
  assert_output --partial 'one or more governance checks failed'
  [ "$(ran_count)" -eq "$(announced_count)" ]
  [ "$(ran_count)" -ge 30 ]
}

@test "aggregates across multiple failing checks" {
  stub_all_ci_checks
  write_stub 'check-uses-sha-pinned' 1
  write_stub 'check-tool-declarations' 1
  GOVERNANCE_CI_DIR_OVERRIDE="${CI}" run_check "${AGG}"
  assert_failure
  assert_output --partial 'one or more governance checks failed'
  [ "$(ran_count)" -eq "$(announced_count)" ]
}

@test "the last roster entry still runs when the first one fails" {
  stub_all_ci_checks
  write_stub 'check-uses-sha-pinned' 1
  GOVERNANCE_CI_DIR_OVERRIDE="${CI}" run_check "${AGG}"
  assert_failure
  # check-tool-declarations is the LAST entry in the roster.
  run grep --fixed-strings --line-regexp 'check-tool-declarations' "${RAN}"
  assert_success
}

@test "a roster entry missing from the check dir fails the run" {
  stub_all_ci_checks
  rm --force "${CI}/check-tool-declarations"
  GOVERNANCE_CI_DIR_OVERRIDE="${CI}" run_check "${AGG}"
  assert_failure
  assert_output --partial 'one or more governance checks failed'
}

@test "does not warn when every check passes" {
  stub_all_ci_checks
  GOVERNANCE_CI_DIR_OVERRIDE="${CI}" run_check "${AGG}"
  assert_success
  refute_output --partial 'one or more governance checks failed'
}
