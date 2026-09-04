setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-harden-runner-disable-sudo-and-containers"
  WF="${BATS_TEST_TMPDIR}/wf"
  mkdir -p "${WF}"
  HR='step-security/harden-runner@ab7a9404c0f3da075243ca237b5fac12c98deaa5'
  # The real EXEMPT list names jobs in the real workflows, which do not exist in
  # the synthetic corpus below — every entry would read as stale. Set-but-empty
  # clears it; tests that need an exemption re-set it on the command itself.
  export EXEMPT_OVERRIDE=''
}

# The check derives its own repo root via `git rev-parse --show-toplevel`.
# common.bash's fixture-escape hardening leaves CWD at BATS_TEST_TMPDIR (outside
# any git repo) by design, so cd into REPO_DIR before every invocation — this
# test targets the real repo.
run_check() {
  cd "${REPO_DIR}" || return 1
  run "$@"
}

# write_job <file> <job> [key:value ...] — one job whose harden-runner step
# carries the given `with:` keys, in order, after egress-policy. With no key
# arguments the step carries egress-policy alone.
write_job() {
  local -r file="$1"
  local -r job="$2"
  shift 2
  {
    printf 'jobs:\n  %s:\n    steps:\n      - uses: %s\n        with:\n' "${job}" "${HR}"
    printf '          egress-policy: block\n'
    local pair
    for pair in "$@"; do
      printf '          %s: %s\n' "${pair%%:*}" "${pair#*:}"
    done
  } > "${WF}/${file}"
}

@test "passes when every job sets disable-sudo-and-containers: true" {
  write_job 'a.yml' 'build' 'disable-sudo-and-containers:true'
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_success
}

@test "fails when a job omits disable-sudo-and-containers" {
  write_job 'a.yml' 'build'
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'want true'
}

@test "fails when disable-sudo-and-containers is explicitly false" {
  write_job 'a.yml' 'build' 'disable-sudo-and-containers:false'
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'want true'
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
  write_job 'a.yml' 'build'
  WORKFLOWS_DIR_OVERRIDE="${WF}" EXEMPT_OVERRIDE='a.yml:build' run_check "${CHECK}"
  assert_success
}

@test "fails when an EXEMPT entry names a job that does not exist" {
  write_job 'a.yml' 'build' 'disable-sudo-and-containers:true'
  WORKFLOWS_DIR_OVERRIDE="${WF}" EXEMPT_OVERRIDE='a.yml:nope' run_check "${CHECK}"
  assert_failure
  assert_output --partial 'stale EXEMPT entry'
}

@test "fails when an EXEMPT entry names a job that already disables sudo and containers" {
  write_job 'a.yml' 'build' 'disable-sudo-and-containers:true'
  WORKFLOWS_DIR_OVERRIDE="${WF}" EXEMPT_OVERRIDE='a.yml:build' run_check "${CHECK}"
  assert_failure
  assert_output --partial 'stale EXEMPT entry'
}

@test "counts violations across multiple jobs in multiple files" {
  write_job 'a.yml' 'build'
  write_job 'b.yml' 'test' 'disable-sudo-and-containers:false'
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial '2 harden-runner hardening violation(s)'
}

# A missing scan target must not read as a clean pass. An absent directory is
# indistinguishable from a directory whose contents are all fine, and this gate is
# what stands between the repo and the thing it checks — the silent-false-green
# shape this repo spends the most effort on, and the rule CLAUDE.md states as
# "Empty scan results are failures, not clean passes".
@test "dies when the workflows directory is absent" {
  WORKFLOWS_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/absent" run_check "${CHECK}"
  assert_failure 1
  assert_output --partial 'does not exist'
}

@test "handles a workflow with several jobs" {
  cat > "${WF}/a.yml" << EOF
jobs:
  one:
    steps:
      - uses: ${HR}
        with:
          egress-policy: block
          disable-sudo-and-containers: true
  two:
    steps:
      - uses: ${HR}
        with:
          egress-policy: block
          disable-sudo-and-containers: true
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

# Distinct from the exempt arm above, which covers a job that HAS a harden-runner
# step: this is the no-step arm, where the exemption is what stops the gate
# reporting a job the maintainer deliberately allowed. The entry is recorded as
# seen so the staleness detection does not then call the exemption unused.
@test "an exempt job with no harden-runner step is accepted" {
  printf 'jobs:\n  build:\n    steps:\n      - uses: actions/checkout@v4\n' > "${WF}/a.yml"
  EXEMPT_OVERRIDE='a.yml:build' WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_success
}

@test "rule 2: fails when a job sets disable-file-monitoring true" {
  write_job 'a.yml' 'build' 'disable-sudo-and-containers:true' 'disable-file-monitoring:true'
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'disable-file-monitoring'
}

@test "rule 2: passes when a job sets disable-file-monitoring false" {
  write_job 'a.yml' 'build' 'disable-sudo-and-containers:true' 'disable-file-monitoring:false'
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_success
}

# Rule 1's EXEMPT array excuses a job from disabling sudo and containers. It does
# not excuse it from the other two rules, which have no exemption array at all.
@test "rule 2 applies to a job that is exempt from rule 1" {
  write_job 'a.yml' 'build' 'disable-file-monitoring:true'
  WORKFLOWS_DIR_OVERRIDE="${WF}" EXEMPT_OVERRIDE='a.yml:build' run_check "${CHECK}"
  assert_failure
  assert_output --partial 'disable-file-monitoring'
}

@test "rule 3: fails when a job sets the deprecated disable-sudo true" {
  write_job 'a.yml' 'build' 'disable-sudo-and-containers:true' 'disable-sudo:true'
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'deprecated disable-sudo'
}

# Value-independent: the key coexisting with its replacement is the defect, not
# the value it carries. A false here would otherwise read as harmless.
@test "rule 3: fails when a job sets the deprecated disable-sudo false" {
  write_job 'a.yml' 'build' 'disable-sudo-and-containers:true' 'disable-sudo:false'
  WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'deprecated disable-sudo'
}

@test "rule 3 applies to a job that is exempt from rule 1" {
  write_job 'a.yml' 'build' 'disable-sudo:true'
  WORKFLOWS_DIR_OVERRIDE="${WF}" EXEMPT_OVERRIDE='a.yml:build' run_check "${CHECK}"
  assert_failure
  assert_output --partial 'deprecated disable-sudo'
}
