#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  SCRIPT="${REPO_DIR}/run-all-checks"
  FAKE_REPO="${BATS_TEST_TMPDIR}/fake-repo"
  mkdir -p "${FAKE_REPO}/.ci"
  # pwd -P so the path matches what `git rev-parse --show-toplevel` reports;
  # BATS_TEST_TMPDIR can sit under a symlinked TMPDIR.
  FAKE_REPO="$(cd "${FAKE_REPO}" && pwd -P)"
  git -C "${FAKE_REPO}" init --quiet
  STEP_LOG="${BATS_TEST_TMPDIR}/steps.log"
}

# Install one stub step inside the fake repo. Every stub appends its own name to
# the shared step log, so both step ordering and no-fail-fast are observable.
# $1 = path relative to the fake repo root, $2 = name logged, $3 = exit code (default 0).
make_step() {
  local -r rel_path="$1"
  local -r name="$2"
  local -r exit_code="${3:-0}"
  cat > "${FAKE_REPO}/${rel_path}" << EOF
#!/usr/bin/env bash
printf '%s\n' '${name}' >> '${STEP_LOG}'
exit ${exit_code}
EOF
  chmod +x "${FAKE_REPO}/${rel_path}"
}

# Stub nix onto PATH so `nix flake check` never touches the real flake.
# $1 = exit code (default 0).
make_nix_step() {
  local -r exit_code="${1:-0}"
  path_shim::add nix "#!/usr/bin/env bash
printf '%s\n' 'nix' >> '${STEP_LOG}'
exit ${exit_code}"
}

# Install all five steps, each passing. Individual tests re-install one of them
# with a failing exit code to exercise that step's failure path.
install_passing_steps() {
  make_step 'check-scripts' 'check-scripts'
  make_step '.ci/run-governance-checks' 'run-governance-checks'
  make_step '.ci/run-lint-checks' 'run-lint-checks'
  make_step 'run-tests' 'run-tests'
  make_nix_step
}

# Stage everything so the tree reads as clean to `git ls-files --others`.
# Deliberately no commit: the maintainer's global commit.gpgsign=true applies
# inside fixture repos too, and staged files are enough for the untracked check.
stage_tree() {
  git -C "${FAKE_REPO}" add --all
}

run_gate() {
  cd "${FAKE_REPO}" || return 1
  run "${SCRIPT}" "$@"
}

# Echo the recorded steps as one space-joined line, for order assertions.
recorded_steps() {
  local -a steps=()
  mapfile -t steps < "${STEP_LOG}"
  local IFS=' '
  printf '%s\n' "${steps[*]}"
}

@test "exits 0 when every step succeeds" {
  install_passing_steps
  stage_tree
  run_gate
  assert_success
}

@test "runs every step, slowest last" {
  install_passing_steps
  stage_tree
  run_gate
  assert_success
  assert_equal "$(recorded_steps)" 'check-scripts nix run-governance-checks run-lint-checks run-tests'
}

@test "exits 1 when check-scripts fails" {
  install_passing_steps
  make_step 'check-scripts' 'check-scripts' 1
  stage_tree
  run_gate
  assert_failure
}

@test "exits 1 when nix flake check fails" {
  install_passing_steps
  make_nix_step 1
  stage_tree
  run_gate
  assert_failure
}

@test "exits 1 when the governance checks fail" {
  install_passing_steps
  make_step '.ci/run-governance-checks' 'run-governance-checks' 1
  stage_tree
  run_gate
  assert_failure
}

@test "exits 1 when the lint checks fail" {
  install_passing_steps
  make_step '.ci/run-lint-checks' 'run-lint-checks' 1
  stage_tree
  run_gate
  assert_failure
}

@test "exits 1 when the test suite fails" {
  install_passing_steps
  make_step 'run-tests' 'run-tests' 1
  stage_tree
  run_gate
  assert_failure
}

@test "does not fail fast: a failing first step does not skip the rest" {
  install_passing_steps
  make_step 'check-scripts' 'check-scripts' 1
  stage_tree
  run_gate
  assert_failure
  assert_equal "$(recorded_steps)" 'check-scripts nix run-governance-checks run-lint-checks run-tests'
}

@test "reports that at least one check failed" {
  install_passing_steps
  make_step 'run-tests' 'run-tests' 1
  stage_tree
  run_gate
  assert_failure
  assert_output --partial 'failed'
}

@test "warns about an untracked file and names it" {
  install_passing_steps
  stage_tree
  printf '%s\n' 'scratch' > "${FAKE_REPO}/scratch.txt"
  run_gate
  assert_output --partial 'untracked'
  assert_output --partial 'scratch.txt'
}

@test "emits no untracked warning on a clean tree" {
  install_passing_steps
  stage_tree
  run_gate
  assert_success
  refute_output --partial 'untracked'
}

@test "an untracked file alone does not fail the run" {
  install_passing_steps
  stage_tree
  printf '%s\n' 'scratch' > "${FAKE_REPO}/scratch.txt"
  run_gate
  assert_success
}

@test "a gitignored file does not trigger the untracked warning" {
  install_passing_steps
  printf '%s\n' 'ignored.txt' > "${FAKE_REPO}/.gitignore"
  stage_tree
  printf '%s\n' 'scratch' > "${FAKE_REPO}/ignored.txt"
  run_gate
  assert_success
  refute_output --partial 'untracked'
}

@test "dies when given an argument" {
  install_passing_steps
  stage_tree
  run_gate oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "--help exits 0 and prints help" {
  install_passing_steps
  stage_tree
  run_gate --help
  assert_success
  assert_output --partial 'run-all-checks'
  assert_output --partial 'Exit codes:'
}
