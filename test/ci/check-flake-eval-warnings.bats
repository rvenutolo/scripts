setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  load '../test_helper/cli_shim'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  load '../test_helper/git_fixture'
  CHECK="${REPO_DIR}/.ci/check-flake-eval-warnings"
  # The check resolves REPO_DIR via `git rev-parse --show-toplevel` and runs nix
  # from there, so it needs a git repo as cwd. common.bash leaves cwd at
  # BATS_TEST_TMPDIR, which is deliberately not a repo (fixture-escape
  # hardening), so give it a throwaway fixture repo. `nix` is stubbed in every
  # case — no test in this suite may shell out to the real thing (see the note in
  # common.bash).
  FIXTURE_REPO="${BATS_TEST_TMPDIR}/repo"
  git_fixture::init "${FIXTURE_REPO}"
  cd "${FIXTURE_REPO}" || return 1
}

# Stub `nix` with canned combined output and exit code, recording every call.
# $1 = output the stub prints, $2 = exit code (default 0).
stub_nix() {
  cli_shim::record_with_output 'nix' "$1" "${2:-0}"
}

@test "passes when flake check is clean and exits 0" {
  stub_nix ''
  run "${CHECK}"
  assert_success
}

@test "passes when flake check prints ordinary output and exits 0" {
  stub_nix 'evaluating flake...
checking flake output '\''formatter'\''...'
  run "${CHECK}"
  assert_success
}

@test "fails when the output carries an evaluation warning" {
  stub_nix "evaluation warning: 'system' has been renamed to 'nixpkgs.hostPlatform'"
  run "${CHECK}"
  assert_failure
}

@test "echoes the evaluation warning line" {
  stub_nix "evaluation warning: 'system' has been renamed to 'nixpkgs.hostPlatform'"
  run "${CHECK}"
  assert_output --partial "evaluation warning: 'system' has been renamed to 'nixpkgs.hostPlatform'"
}

@test "echoes every evaluation warning line, not just the first" {
  stub_nix 'evaluation warning: first offender
checking flake output '\''checks'\''...
evaluation warning: second offender
evaluation warning: third offender'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'evaluation warning: first offender'
  assert_output --partial 'evaluation warning: second offender'
  assert_output --partial 'evaluation warning: third offender'
}

@test "finds an evaluation warning surrounded by other output" {
  stub_nix 'evaluating flake...
evaluation warning: buried in the middle
checking flake output '\''devShells'\''...'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'evaluation warning: buried in the middle'
}

@test "fails when nix exits non-zero even with no evaluation warning" {
  # The check is a superset of the bare `nix flake check` step it replaces, so
  # flake check's own failures must still fail the gate.
  stub_nix 'error: builder for /nix/store/xxx.drv failed' 1
  run "${CHECK}"
  assert_failure
}

@test "surfaces flake check's own output when it fails" {
  stub_nix 'error: builder for /nix/store/xxx.drv failed' 1
  run "${CHECK}"
  assert_failure
  assert_output --partial 'error: builder for /nix/store/xxx.drv failed'
}

@test "fails when nix exits non-zero and emits an evaluation warning" {
  stub_nix 'evaluation warning: deprecated option
error: flake check failed' 1
  run "${CHECK}"
  assert_failure
  assert_output --partial 'evaluation warning: deprecated option'
}

@test "propagates a non-zero exit even when nix produces no output at all" {
  stub_nix '' 1
  run "${CHECK}"
  assert_failure
}

@test "does not fail on a plain warning that is not an evaluation warning" {
  # Nix emits `warning: Git tree ... is dirty` on nearly every local run. Only
  # `evaluation warning:` lines are in scope; treating every warning as fatal
  # would make the gate unusable.
  stub_nix "warning: Git tree '/home/user/repo' is dirty"
  run "${CHECK}"
  assert_success
}

@test "invokes nix with --no-eval-cache" {
  # Without --no-eval-cache the evaluation cache suppresses warning lines after
  # the first run, so a warm local gate is quieter than cold CI.
  stub_nix ''
  run "${CHECK}"
  assert_success
  assert_equal "$(cli_shim::calls nix)" 'flake check --no-eval-cache'
}

@test "invokes nix exactly once" {
  stub_nix ''
  run "${CHECK}"
  assert_success
  assert_equal "$(cli_shim::call_count nix)" '1'
}

@test "still runs flake check when a warning is present" {
  stub_nix 'evaluation warning: something'
  run "${CHECK}"
  assert_failure
  assert_equal "$(cli_shim::calls nix)" 'flake check --no-eval-cache'
}

@test "rejects an unexpected argument" {
  stub_nix ''
  run "${CHECK}" unexpected
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "rejects two unexpected arguments" {
  stub_nix ''
  run "${CHECK}" one two
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "--help exits 0 and prints the description" {
  stub_nix ''
  run "${CHECK}" --help
  assert_success
  assert_output --partial 'evaluation warning'
}

@test "-h exits 0 and prints the description" {
  stub_nix ''
  run "${CHECK}" -h
  assert_success
  assert_output --partial 'evaluation warning'
}

@test "--help does not invoke nix" {
  stub_nix ''
  run "${CHECK}" --help
  assert_success
  assert_equal "$(cli_shim::call_count nix)" '0'
}
