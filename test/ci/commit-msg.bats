setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  load '../test_helper/cli_shim'
  HOOK="${REPO_DIR}/.githooks/commit-msg"
  MSG_FILE="${BATS_TEST_TMPDIR}/COMMIT_EDITMSG"
  printf '%s\n' 'feat: add a thing' > "${MSG_FILE}"
}

# The hook derives no repo root of its own, so common.bash's fixture-escape hardening
# leaving CWD at BATS_TEST_TMPDIR is fine here — unlike the .ci/ checks, which must cd
# into REPO_DIR.
#
# BASH_ENV is neutralized on every invocation: the hook's own `#!/usr/bin/env bash` startup
# would re-source ~/.bashrc, re-prepending the real nix PATH ahead of the commitlint shim.
# SAFE_BASH_ENV rather than a literal '' keeps kcov's trace helper attached.
run_hook() {
  BASH_ENV="${SAFE_BASH_ENV}" run "$@"
}

@test "--help exits 0 and prints help derived from the shdoc header" {
  run_hook "${HOOK}" --help
  assert_success
  assert_output --partial 'commitlint'
}

@test "dies when given no arguments" {
  run_hook "${HOOK}"
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "dies when given two arguments" {
  run_hook "${HOOK}" "${MSG_FILE}" 'extra'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "passes the commit message file to commitlint --edit" {
  cli_shim::record 'commitlint'
  run_hook "${HOOK}" "${MSG_FILE}"
  assert_success
  run cli_shim::calls 'commitlint'
  assert_output "--edit ${MSG_FILE}"
}

@test "fails when commitlint rejects the message" {
  cli_shim::record_with_output 'commitlint' 'subject may not be empty' 1
  run_hook "${HOOK}" "${MSG_FILE}"
  assert_failure 1
}

@test "dies with a bypass hint when commitlint is not installed" {
  path_shim::mkbin
  PATH="${BATS_TEST_TMPDIR}/bin:/usr/bin:/bin" run_hook "${HOOK}" "${MSG_FILE}"
  assert_failure
  assert_output --partial 'commitlint not found'
  assert_output --partial '--no-verify'
}

# Pins the decision recorded in CLAUDE.md, "Gates run inside the hermetic devShell":
# this hook is deliberately OUTSIDE the .ci/in-devshell boundary every other gate goes
# through, because wrapping it would buy a nix evaluation on every single commit in
# exchange for resolving one binary. Nothing else verifies that decision still holds.
#
# A poison `nix` is what makes the assertion behavioral rather than a source grep: if the
# hook ever grew an in-devshell call, the wrapper would evaluate the flake, the poison
# would fire, and this test would name the reason.
@test "resolves commitlint from the ambient PATH without evaluating the flake" {
  cli_shim::record 'commitlint'
  path_shim::add 'nix' '#!/usr/bin/env bash
printf "poisoned\n" > "'"${BATS_TEST_TMPDIR}"'/nix.marker"
exit 42'
  run_hook "${HOOK}" "${MSG_FILE}"
  assert_success
  run cat "${BATS_TEST_TMPDIR}/nix.marker"
  assert_failure 1
}
