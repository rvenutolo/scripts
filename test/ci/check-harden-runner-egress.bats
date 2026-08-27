setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-harden-runner-egress"
  WF="${BATS_TEST_TMPDIR}/wf"
  mkdir -p "${WF}"
  HR='step-security/harden-runner@ab7a9404c0f3da075243ca237b5fac12c98deaa5'
}

# .ci/check-harden-runner-egress derives its own repo root via `git rev-parse
# --show-toplevel`. common.bash's fixture-escape hardening leaves CWD at
# BATS_TEST_TMPDIR (outside any git repo) by design, so cd into REPO_DIR before
# every invocation — this test targets the real repo.
run_check() {
  cd "${REPO_DIR}" || return 1
  run "$@"
}

# write_job <file> <job> <policy> <endpoints> — one job whose harden-runner step
# uses the given policy. An empty endpoints arg omits the key entirely.
write_job() {
  local -r file="$1"
  local -r job="$2"
  local -r policy="$3"
  local -r endpoints="$4"
  {
    printf 'jobs:\n  %s:\n    steps:\n      - uses: %s\n        with:\n' "${job}" "${HR}"
    printf '          egress-policy: %s\n' "${policy}"
    if [[ -n "${endpoints}" ]]; then
      printf '          allowed-endpoints: >-\n            %s\n' "${endpoints}"
    fi
  } > "${WF}/${file}"
}

@test "passes when every job blocks with a non-empty allowed-endpoints" {
  write_job 'a.yml' 'build' 'block' 'github.com:443'
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_success
}

@test "fails when a job is still on audit" {
  write_job 'a.yml' 'build' 'audit' ''
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'egress-policy'
}

@test "fails when a blocking job has no allowed-endpoints key" {
  write_job 'a.yml' 'build' 'block' ''
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'allowed-endpoints'
}

@test "fails when allowed-endpoints is present but blank" {
  cat > "${WF}/a.yml" << EOF
jobs:
  build:
    steps:
      - uses: ${HR}
        with:
          egress-policy: block
          allowed-endpoints: '   '
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'allowed-endpoints'
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

@test "passes an audit job that is listed in EXEMPT" {
  write_job 'a.yml' 'build' 'audit' ''
  WORKFLOWS_DIR_OVERRIDE="${WF}" EXEMPT_OVERRIDE='a.yml:build' run_check "${CHECK}"
  assert_success
}

@test "fails when an EXEMPT entry names a job that does not exist" {
  write_job 'a.yml' 'build' 'block' 'github.com:443'
  WORKFLOWS_DIR_OVERRIDE="${WF}" EXEMPT_OVERRIDE='a.yml:nope' run_check "${CHECK}"
  assert_failure
  assert_output --partial 'stale EXEMPT entry'
}

@test "fails when an EXEMPT entry names a job that already blocks" {
  write_job 'a.yml' 'build' 'block' 'github.com:443'
  WORKFLOWS_DIR_OVERRIDE="${WF}" EXEMPT_OVERRIDE='a.yml:build' run_check "${CHECK}"
  assert_failure
  assert_output --partial 'stale EXEMPT entry'
}

@test "counts violations across multiple jobs in multiple files" {
  write_job 'a.yml' 'build' 'audit' ''
  write_job 'b.yml' 'test' 'block' ''
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
          allowed-endpoints: >-
            github.com:443
  two:
    steps:
      - uses: ${HR}
        with:
          egress-policy: block
          allowed-endpoints: >-
            api.github.com:443
EOF
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_success
}

@test "dies when given an argument" {
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "a workflow yq cannot parse aborts instead of inventing a finding" {
  # The harden-runner presence check must stay a plain command. As a predicate
  # called from an `if` it disables errexit for its whole call tree: a yq failure
  # leaves an empty count, the arithmetic reads it as zero, and the job is reported
  # as having no harden-runner step — a finding manufactured from a parse error.
  printf -- '- a\n- b\n' > "${WF}/seq.yml"
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  refute_output --partial 'has no harden-runner step'
}

# The EXEMPT array ships empty on purpose, so its arm is only reachable through the
# override seam — and an exemption that silently stopped working would leave the gate
# looking correct while failing a job the maintainer had deliberately allowed. The
# entry is also recorded as seen, which is what the staleness detection reads.
@test "an exempt job with no harden-runner step is accepted" {
  printf 'jobs:\n  build:\n    steps:\n      - uses: actions/checkout@v4\n' > "${WF}/a.yml"
  EXEMPT_OVERRIDE='a.yml:build' WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_success
}
