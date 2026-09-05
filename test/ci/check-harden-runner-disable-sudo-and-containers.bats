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
  export CONTAINERS_EXEMPT_OVERRIDE=''
  # Rule 4 pins the harden-runner ref the containers tier was validated against.
  # The array and the ref travel together — either one alone is a violation — so
  # both start empty here, and a test that sets one sets the other.
  export CONTAINERS_EXEMPT_HARDEN_RUNNER_REF_OVERRIDE=''
  HR_REF="${HR#*@}"
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

# run_containers_check <entries> — run the check with the containers tier
# configured: the CONTAINERS_EXEMPT entries plus the ref the fixture's
# harden-runner step is pinned at, which Rule 4 requires alongside them.
run_containers_check() {
  CONTAINERS_EXEMPT_OVERRIDE="$1" \
    CONTAINERS_EXEMPT_HARDEN_RUNNER_REF_OVERRIDE="${HR_REF}" \
    WORKFLOWS_DIR_OVERRIDE="${WF}" run_check "${CHECK}"
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

# --- CONTAINERS_EXEMPT: jobs that need a container runtime -------------------
# The superset input does not merely deny container access, it purges the
# runtime. A job that needs one therefore takes the deprecated disable-sudo,
# which is the strongest hardening left to it, and is the only kind of job the
# deprecated key is permitted on.

@test "containers-exempt: passes when the job sets disable-sudo true" {
  write_job 'a.yml' 'build' 'disable-sudo:true'
  run_containers_check 'a.yml:build'
  assert_success
}

@test "containers-exempt: fails when the job sets neither key" {
  write_job 'a.yml' 'build'
  run_containers_check 'a.yml:build'
  assert_failure
  assert_output --partial 'must set disable-sudo true'
}

# The key without the hardening. Testing for presence rather than for the value
# would let this through.
@test "containers-exempt: fails when the job sets disable-sudo false" {
  write_job 'a.yml' 'build' 'disable-sudo:false'
  run_containers_check 'a.yml:build'
  assert_failure
  assert_output --partial 'must set disable-sudo true'
}

@test "containers-exempt: fails when the job also sets the superset" {
  write_job 'a.yml' 'build' 'disable-sudo:true' 'disable-sudo-and-containers:true'
  run_containers_check 'a.yml:build'
  assert_failure
  assert_output --partial 'stale CONTAINERS_EXEMPT entry'
}

# Presence, not value: the superset at false alongside the deprecated key is the
# coexistence the deprecation rule exists to prevent, and a job that can set the
# superset at all does not belong in this array.
@test "containers-exempt: fails when the job sets the superset false" {
  write_job 'a.yml' 'build' 'disable-sudo:true' 'disable-sudo-and-containers:false'
  run_containers_check 'a.yml:build'
  assert_failure
  assert_output --partial 'stale CONTAINERS_EXEMPT entry'
}

@test "containers-exempt: fails when the entry names a job that does not exist" {
  write_job 'a.yml' 'build' 'disable-sudo-and-containers:true'
  run_containers_check 'a.yml:nope'
  assert_failure
  assert_output --partial 'stale CONTAINERS_EXEMPT entry: a.yml:nope matches no job'
}

# Unlike the EXEMPT arm, a missing harden-runner step is not tolerated here: the
# entry asserts the job takes a specific input, which it cannot do without one.
# Reported once, as the missing step, not also as a stale entry.
@test "containers-exempt: fails when the job has no harden-runner step" {
  printf 'jobs:\n  build:\n    steps:\n      - uses: actions/checkout@v4\n' > "${WF}/a.yml"
  run_containers_check 'a.yml:build'
  assert_failure
  assert_output --partial 'no harden-runner step'
  refute_output --partial 'matches no job'
}

@test "rule 2 applies to a containers-exempt job" {
  write_job 'a.yml' 'build' 'disable-sudo:true' 'disable-file-monitoring:true'
  run_containers_check 'a.yml:build'
  assert_failure
  assert_output --partial 'disable-file-monitoring'
}

# The two arrays demand incompatible configurations — neither key versus the
# deprecated key — so an entry in both would otherwise be resolved by whichever
# lookup ran first, silently.
@test "an entry in both arrays is rejected before any job is examined" {
  write_job 'a.yml' 'build' 'disable-sudo:true'
  EXEMPT_OVERRIDE='a.yml:build' run_containers_check 'a.yml:build'
  assert_failure
  assert_output --partial 'appears in both EXEMPT and CONTAINERS_EXEMPT'
}

# --- Rule 4: the containers tier is pinned to a validated harden-runner ref ---
# Upstream marks `disable-sudo` for removal. When it goes, Actions reports an
# unknown input as a warning annotation rather than an error: the job stays
# green and runs with sudo enabled, and Renovate automerges the bump that did
# it. A gate cannot ask upstream whether the input still exists, so it pins the
# ref the tier was verified against and goes red when those jobs move off it.

@test "rule 4: passes when a containers-exempt job pins the validated ref" {
  write_job 'a.yml' 'build' 'disable-sudo:true'
  run_containers_check 'a.yml:build'
  assert_success
}

@test "rule 4: fails when a containers-exempt job pins a different ref" {
  write_job 'a.yml' 'build' 'disable-sudo:true'
  WORKFLOWS_DIR_OVERRIDE="${WF}" CONTAINERS_EXEMPT_OVERRIDE='a.yml:build' \
    CONTAINERS_EXEMPT_HARDEN_RUNNER_REF_OVERRIDE='0000000000000000000000000000000000000000' \
    run_check "${CHECK}"
  assert_failure
  assert_output --partial 'was validated against'
  assert_output --partial 'still accepts the disable-sudo input'
  assert_output --partial '1 harden-runner hardening violation(s)'
}

# Scoped to the tier. The constant asserts that one release still carries the
# input those two jobs depend on; it says nothing about the eighteen other
# harden-runner steps, and pinning them here would redden an ordinary grouped
# bump over jobs whose posture the bump cannot change.
@test "rule 4: a job outside the tier may pin any ref" {
  cat > "${WF}/a.yml" << EOF
jobs:
  build:
    steps:
      - uses: ${HR}
        with:
          egress-policy: block
          disable-sudo: true
  other:
    steps:
      - uses: step-security/harden-runner@0000000000000000000000000000000000000000
        with:
          egress-policy: block
          disable-sudo-and-containers: true
EOF
  run_containers_check 'a.yml:build'
  assert_success
}

@test "rule 4: fails when the tier has entries but no ref is pinned" {
  write_job 'a.yml' 'build' 'disable-sudo:true'
  WORKFLOWS_DIR_OVERRIDE="${WF}" CONTAINERS_EXEMPT_OVERRIDE='a.yml:build' run_check "${CHECK}"
  assert_failure
  assert_output --partial 'CONTAINERS_EXEMPT is not empty'
}

# Reported once, against the constant. Comparing every job against an empty
# constant would report the same defect a second time, per job, and point the
# reader at a workflow whose pin is not what is wrong.
@test "rule 4: a missing pin is not also reported per job" {
  write_job 'a.yml' 'build' 'disable-sudo:true'
  WORKFLOWS_DIR_OVERRIDE="${WF}" CONTAINERS_EXEMPT_OVERRIDE='a.yml:build' run_check "${CHECK}"
  assert_failure
  assert_output --partial '1 harden-runner hardening violation(s)'
  refute_output --partial 'was validated against'
}

# The reverse direction. When both jobs move off Docker the array empties, and a
# constant left behind would go red on the next grouped bump telling the reader
# to re-verify an input that no job takes.
@test "rule 4: fails when a ref is pinned for an empty tier" {
  write_job 'a.yml' 'build' 'disable-sudo-and-containers:true'
  WORKFLOWS_DIR_OVERRIDE="${WF}" \
    CONTAINERS_EXEMPT_HARDEN_RUNNER_REF_OVERRIDE="${HR_REF}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'stale CONTAINERS_EXEMPT_HARDEN_RUNNER_REF'
}
