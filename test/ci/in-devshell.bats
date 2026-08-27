# shellcheck disable=SC2030,SC2031 # BATS runs each @test in a subshell; the IN_DEVSHELL exports are intentional and correctly scoped per-test
# shellcheck disable=SC2016 # the nix stub bodies are literal shell text, expanded by the stub when it runs, never here
bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  load '../test_helper/cli_shim'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  load '../test_helper/git_fixture'
  WRAPPER="${REPO_DIR}/.ci/in-devshell"
  # Resolve the tmpdir with pwd -P: BATS_TEST_TMPDIR can sit under a symlinked
  # TMPDIR, and `git rev-parse --show-toplevel` reports the symlink-free path, so
  # the flake-reference assertions would compare two spellings of one directory.
  TMP_ROOT="$(cd "${BATS_TEST_TMPDIR}" && pwd -P)"
  REPO="${TMP_ROOT}/repo"
  git_fixture::init "${REPO}"
  # The wrapper short-circuits to a bare exec when IN_DEVSHELL is set. Once the
  # suite itself runs inside the wrapper the sentinel is exported into every
  # test, so without this unset every wrap-path case below would silently assert
  # nothing while still passing.
  unset IN_DEVSHELL
  unset IN_DEVSHELL_KEEP
}

# The fixed --keep allowlist, spelled out here as the specification the wrapper
# is held to rather than read back out of the script under test.
EXPECTED_KEEPS=(
  HOME
  TERM
  CI
  SCRIPTS_DIR
  IN_DEVSHELL
  NIX_SSL_CERT_FILE
  GITHUB_ACTIONS
  GITHUB_OUTPUT
  GITHUB_ENV
  GITHUB_STEP_SUMMARY
  GITHUB_WORKSPACE
  GITHUB_REPOSITORY
  GITHUB_REF
  GITHUB_REF_NAME
  GITHUB_SHA
  GITHUB_EVENT_NAME
  GITHUB_TOKEN
  GH_TOKEN
  GH_REPO
  RUNNER_OS
  RUNNER_TEMP
)

# Stub `nix` with a recorder so the wrapper's `exec nix ...` lands on the stub and
# its argv is captured. No test in this suite may shell out to the real nix (see
# the note in common.bash).
stub_nix() {
  cli_shim::record 'nix'
}

# Stub `nix` with one that reports the environment it was handed, for the cases
# that assert on exported variables rather than on argv.
stub_nix_reporting_env() {
  path_shim::add 'nix' '#!/usr/bin/env bash
printf "SCRIPTS_DIR=%s\n" "${SCRIPTS_DIR:-UNSET}"
printf "IN_DEVSHELL=%s\n" "${IN_DEVSHELL:-UNSET}"
exit 0'
}

# Stub `nix` with a poison pill: any invocation is a test failure, loudly.
stub_nix_poison() {
  path_shim::add 'nix' '#!/usr/bin/env bash
printf "POISONED: nix was invoked\n" >&2
exit 42'
}

# The wrapper resolves its flake reference from `git rev-parse --show-toplevel`,
# so it needs a git repo as cwd. common.bash leaves cwd at BATS_TEST_TMPDIR,
# which is deliberately not a repo (fixture-escape hardening).
run_wrapper() {
  cd "${REPO}" || return 1
  run "${WRAPPER}" "$@"
}

# Count the `--keep` flags on the single recorded nix invocation.
keep_count() {
  cli_shim::calls 'nix' | grep --only-matching -e '--keep' | wc --lines
}

@test "wipes the caller's environment with --ignore-environment" {
  stub_nix
  run_wrapper echo hello
  assert_success
  run cli_shim::calls 'nix'
  assert_output --partial '--ignore-environment'
}

@test "keeps every variable on the fixed allowlist, set or not" {
  stub_nix
  run_wrapper echo hello
  assert_success
  run cli_shim::calls 'nix'
  local name
  for name in "${EXPECTED_KEEPS[@]}"; do
    assert_output --partial "--keep ${name}"
  done
}

@test "IN_DEVSHELL_KEEP appends each name to the keep list" {
  stub_nix
  export IN_DEVSHELL_KEEP='FOO BAR'
  run_wrapper echo hello
  assert_success
  run cli_shim::calls 'nix'
  assert_output --partial '--keep FOO'
  assert_output --partial '--keep BAR'
}

@test "IN_DEVSHELL_KEEP unset adds nothing beyond the fixed allowlist" {
  stub_nix
  run_wrapper echo hello
  assert_success
  run keep_count
  assert_output "${#EXPECTED_KEEPS[@]}"
}

@test "IN_DEVSHELL_KEEP empty adds nothing and emits no stray --keep" {
  stub_nix
  export IN_DEVSHELL_KEEP=''
  run_wrapper echo hello
  assert_success
  run keep_count
  assert_output "${#EXPECTED_KEEPS[@]}"
}

@test "the flake reference is the invoking repo root, not the ambient repo" {
  stub_nix
  run_wrapper echo hello
  assert_success
  run cli_shim::calls 'nix'
  assert_output --partial "develop ${REPO} --ignore-environment"
  refute_output --partial "develop ${REPO_DIR} "
}

@test "forwards the command and its arguments verbatim after --command" {
  stub_nix
  run_wrapper echo hello 'two words' --flag
  assert_success
  run cli_shim::calls 'nix'
  assert_output --partial '--command echo hello two words --flag'
}

@test "exports SCRIPTS_DIR as <repo>/scripts and the IN_DEVSHELL sentinel" {
  stub_nix_reporting_env
  run_wrapper echo hello
  assert_success
  assert_output --partial "SCRIPTS_DIR=${REPO}/scripts"
  assert_output --partial 'IN_DEVSHELL=1'
}

@test "runs the command directly and never invokes nix when already inside" {
  stub_nix_poison
  export IN_DEVSHELL=1
  run_wrapper echo NESTED_OK
  assert_success
  assert_output 'NESTED_OK'
  refute_output --partial 'POISONED'
}

@test "nesting short-circuit forwards arguments verbatim" {
  stub_nix_poison
  export IN_DEVSHELL=1
  run_wrapper printf '%s|%s\n' 'a b' 'c'
  assert_success
  assert_output 'a b|c'
}

@test "dies with a usage line when given no arguments" {
  stub_nix
  cd "${REPO}" || return 1
  run --separate-stderr "${WRAPPER}"
  assert_failure 1
  assert_stderr --partial 'usage:'
  assert_stderr --partial 'in-devshell'
}

@test "dies when the working directory is not inside a git repo" {
  stub_nix
  cd "${TMP_ROOT}" || return 1
  run --separate-stderr "${WRAPPER}" echo hello
  assert_failure 1
  assert_stderr --partial 'not a git repo'
}
