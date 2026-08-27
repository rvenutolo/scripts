setup() {
  load '../test_helper/common'
  # git_fixture's guards are args::check_* calls; common.bash sources only log.bash.
  # shellcheck disable=SC1091 # path resolved at runtime via SCRIPTS_DIR
  source "${SCRIPTS_DIR}/functions/args.bash"
  load '../test_helper/git_fixture'
  HOOK="${REPO_DIR}/.githooks/pre-push"
  FAKE_REPO="${BATS_TEST_TMPDIR}/fake-repo"
  mkdir --parents "${FAKE_REPO}"
  # pwd -P so the path matches what `git rev-parse --show-toplevel` reports;
  # BATS_TEST_TMPDIR can sit under a symlinked TMPDIR.
  FAKE_REPO="$(cd "${FAKE_REPO}" && pwd -P)"
  git_fixture::init "${FAKE_REPO}"
  mkdir --parents "${FAKE_REPO}/.ci"
  GATE_ARGV="${BATS_TEST_TMPDIR}/gate.argv"
  GATE_ENV="${BATS_TEST_TMPDIR}/gate.env"
}

# write_gate_stub <exit_code> — stand in for .ci/in-devshell inside the fixture repo.
# Records its argv and the environment it was handed, then exits with the given code.
#
# Dumping the environment is what lets a test assert the fixture-escape defense directly:
# the hook must call git::clear_local_env before running anything, so the repo-scoped GIT_*
# vars a worktree push exports cannot reach the BATS suite the gate goes on to run.
# Asserting the effect beats asserting the call — the retargeting is what matters.
write_gate_stub() {
  local -r code="$1"
  cat > "${FAKE_REPO}/.ci/in-devshell" << EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > '${GATE_ARGV}'
env > '${GATE_ENV}'
exit ${code}
EOF
  chmod +x "${FAKE_REPO}/.ci/in-devshell"
}

# PRE_PUSH_GATE_DIR_OVERRIDE points the hook's gate invocation at the fixture, so these
# tests never run the real ./run-all-checks — which would take minutes and recurse into
# this very suite. Production leaves it unset. The hook still resolves its own REPO_DIR
# via `git rev-parse --show-toplevel`, which is why CWD is the fixture repo.
#
# BASH_ENV is neutralized for the same reason as everywhere else in the suite, using
# SAFE_BASH_ENV so kcov's trace helper survives.
run_hook() {
  cd "${FAKE_REPO}" || return 1
  PRE_PUSH_GATE_DIR_OVERRIDE="${FAKE_REPO}" BASH_ENV="${SAFE_BASH_ENV}" run "$@"
}

@test "exits 0 when the gate passes" {
  write_gate_stub 0
  run_hook "${HOOK}"
  assert_success
  assert_output --partial 'gate passed'
}

@test "aborts the push when the gate fails" {
  write_gate_stub 1
  run_hook "${HOOK}"
  assert_failure 1
  assert_output --partial 'push aborted'
}

@test "runs run-all-checks through the in-devshell wrapper" {
  write_gate_stub 0
  run_hook "${HOOK}"
  assert_success
  run cat "${GATE_ARGV}"
  assert_success
  assert_output "${FAKE_REPO}/run-all-checks"
}

# A worktree `git push` exports an absolute GIT_DIR into this hook, and the gate below runs
# the BATS suite, so without a defense every fixture git command in that suite is retargeted
# at the real repo — rewriting a branch, writing commit.gpgsign=false into the shared
# config. git::clear_local_env is the defense; this asserts it takes effect.
@test "strips the inherited GIT_DIR that would retarget the suite at the real repo" {
  write_gate_stub 0
  cd "${FAKE_REPO}"
  PRE_PUSH_GATE_DIR_OVERRIDE="${FAKE_REPO}" BASH_ENV="${SAFE_BASH_ENV}" \
    GIT_DIR="${FAKE_REPO}/.git" GIT_INDEX_FILE="${FAKE_REPO}/.git/index" \
    PRE_PUSH_CONTROL='reached' run "${HOOK}"
  assert_success
  # Positive control first: an ordinary exported var does reach the gate. Without it the
  # negative below would pass just as happily on an empty or unwritten dump.
  run grep --fixed-strings --line-regexp 'PRE_PUSH_CONTROL=reached' "${GATE_ENV}"
  assert_success
  run grep --extended-regexp '^GIT_(DIR|INDEX_FILE)=' "${GATE_ENV}"
  assert_failure 1
}

@test "ignores the ref/sha pairs git feeds it on stdin" {
  write_gate_stub 0
  cd "${FAKE_REPO}"
  PRE_PUSH_GATE_DIR_OVERRIDE="${FAKE_REPO}" BASH_ENV="${SAFE_BASH_ENV}" \
    run bash -c 'printf "refs/heads/main abc refs/heads/main def\n" | "$1"' _ "${HOOK}"
  assert_success
}

@test "ignores the positional args git passes (pass-through, no arity guard)" {
  write_gate_stub 0
  run_hook "${HOOK}" 'origin' 'git@github.com:owner/repo.git'
  assert_success
}
