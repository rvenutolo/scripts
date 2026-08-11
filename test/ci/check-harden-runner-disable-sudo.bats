setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-harden-runner-disable-sudo"
  WF="${BATS_TEST_TMPDIR}/wf"
  mkdir -p "${WF}"
  HR='step-security/harden-runner@ab7a9404c0f3da075243ca237b5fac12c98deaa5'
  # The real EXEMPT list names jobs in the real workflows, which do not exist in
  # the synthetic corpus below — every entry would read as stale. Set-but-empty
  # clears it; tests that need an exemption re-set it on the command itself.
  export EXEMPT_OVERRIDE=''
}

# .ci/check-harden-runner-disable-sudo derives its own repo root via
# `git rev-parse --show-toplevel`. common.bash's #248 hardening leaves CWD at
# BATS_TEST_TMPDIR (outside any git repo) by design, so cd into REPO_DIR before
# every invocation — this test targets the real repo.
run_check() {
  cd "${REPO_DIR}" || return 1
  run "$@"
}

# write_job <file> <job> <disable_sudo> — one job whose harden-runner step sets
# the given disable-sudo value. An empty value omits the key entirely.
write_job() {
  local -r file="$1"
  local -r job="$2"
  local -r disable_sudo="$3"
  {
    printf 'jobs:\n  %s:\n    steps:\n      - uses: %s\n        with:\n' "${job}" "${HR}"
    printf '          egress-policy: block\n'
    if [[ -n "${disable_sudo}" ]]; then
      printf '          disable-sudo: %s\n' "${disable_sudo}"
    fi
  } > "${WF}/${file}"
}

@test "passes when every job sets disable-sudo: true" {
  write_job 'a.yml' 'build' 'true'
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_success
}

@test "fails when a job omits disable-sudo" {
  write_job 'a.yml' 'build' ''
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'disable-sudo'
}

@test "fails when disable-sudo is explicitly false" {
  write_job 'a.yml' 'build' 'false'
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'disable-sudo'
}

@test "fails when a job has no harden-runner step at all" {
  cat > "${WF}/a.yml" << 'EOF'
jobs:
  build:
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'no harden-runner step'
}

@test "passes a job that is listed in EXEMPT" {
  write_job 'a.yml' 'build' ''
  WORKFLOWS_DIR_OVERRIDE="${WF}" EXEMPT_OVERRIDE='a.yml:build' run_check "${CHECK}"
  assert_success
}

@test "fails when an EXEMPT entry names a job that does not exist" {
  write_job 'a.yml' 'build' 'true'
  WORKFLOWS_DIR_OVERRIDE="${WF}" EXEMPT_OVERRIDE='a.yml:nope' run_check "${CHECK}"
  assert_failure
  assert_output --partial 'stale EXEMPT entry'
}

@test "fails when an EXEMPT entry names a job that already disables sudo" {
  write_job 'a.yml' 'build' 'true'
  WORKFLOWS_DIR_OVERRIDE="${WF}" EXEMPT_OVERRIDE='a.yml:build' run_check "${CHECK}"
  assert_failure
  assert_output --partial 'stale EXEMPT entry'
}

@test "counts violations across multiple jobs in multiple files" {
  write_job 'a.yml' 'build' ''
  write_job 'b.yml' 'test' 'false'
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial '2 job(s)'
}

@test "passes when the workflows directory does not exist" {
  WORKFLOWS_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/absent" run_check "${CHECK}"
  assert_success
}

@test "handles a workflow with several jobs" {
  cat > "${WF}/a.yml" << EOF
jobs:
  one:
    steps:
      - uses: ${HR}
        with:
          egress-policy: block
          disable-sudo: true
  two:
    steps:
      - uses: ${HR}
        with:
          egress-policy: block
          disable-sudo: true
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_success
}

@test "dies when given an argument" {
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}
