bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # Sourced for make_guard_bin, which resolves real binary paths the same
  # way the runner does — command -v would return repo wrappers instead.
  # shellcheck disable=SC1091 # paths resolved at runtime via SCRIPTS_DIR
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091 # paths resolved at runtime via SCRIPTS_DIR
  source "${SCRIPTS_DIR}/functions/path.bash"
  # shellcheck disable=SC1091 # paths resolved at runtime via SCRIPTS_DIR
  source "${SCRIPTS_DIR}/functions/commands.bash"
  # shellcheck disable=SC1091 # paths resolved at runtime via SCRIPTS_DIR
  source "${SCRIPTS_DIR}/functions/log.bash"
  load '../test_helper/git_fixture'
  SCRIPT="${REPO_DIR}/run-tests"
  FAKE_REPO="${BATS_TEST_TMPDIR}/fake-repo"
  mkdir -p "${FAKE_REPO}"
  # pwd -P so the path matches what `git rev-parse --show-toplevel` reports;
  # BATS_TEST_TMPDIR can sit under a symlinked TMPDIR.
  FAKE_REPO="$(cd "${FAKE_REPO}" && pwd -P)"
  git_fixture::init "${FAKE_REPO}"
  # The mutation-tripwire tests need a resolvable HEAD and a committer identity
  # (GIT_CONFIG_GLOBAL is /dev/null in this harness — see common.bash), so every
  # test in this file gets a configured identity and an initial commit.
  git_fixture::run "${FAKE_REPO}" config user.email 'bats@example.invalid'
  git_fixture::run "${FAKE_REPO}" config user.name 'Bats Test'
  git_fixture::run "${FAKE_REPO}" commit --quiet --allow-empty --message 'initial commit'
  ARGS_LOG="${BATS_TEST_TMPDIR}/bats-args.log"
  # The runner resolves bats from PATH, so the recording stub is a PATH shim
  # prepended ahead of the devShell's real bats.
  STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
  mkdir --parents "${STUB_BIN}"
}

# Write an executable `bats` into $1 that records its argv to ARGS_LOG, runs the
# optional body in $2, and exits 0. Recording rather than executing is what
# prevents these tests from invoking the real bats binary.
write_bats_stub() {
  local -r bin_dir="$1"
  local -r body="$2"
  cat > "${bin_dir}/bats" << EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "${ARGS_LOG}"
${body}
exit 0
EOF
  chmod +x "${bin_dir}/bats"
}

# Install the plain recording stub on the shim dir run_in_fake_repo prepends.
install_bats_stub() {
  write_bats_stub "${STUB_BIN}" ''
}

# Like install_bats_stub, but runs the given body line(s) before exiting 0 —
# used to simulate the suite mutating the surrounding fixture repo.
make_recording_bats_stub_with_body() {
  local -r body="$1"
  write_bats_stub "${STUB_BIN}" "${body}"
}

run_in_fake_repo() {
  cd "${FAKE_REPO}" || return 1
  # BASH_ENV=SAFE_BASH_ENV: a child bash would otherwise re-source the user's
  # interactive ~/.bashrc, restoring the real PATH ahead of the stub dir. Unsetting
  # it outright also detaches kcov's trace helper, so run-tests reads 0%.
  run env "BASH_ENV=${SAFE_BASH_ENV}" PATH="${STUB_BIN}:${PATH}" "${SCRIPT}" "$@"
}

# Run the script against an exact PATH ($1), with no ambient entries at all —
# the only way to prove a guard fires on a genuinely missing tool.
run_in_fake_repo_with_path() {
  local -r bin_dir="$1"
  shift
  cd "${FAKE_REPO}" || return 1
  run env "BASH_ENV=${SAFE_BASH_ENV}" PATH="${bin_dir}" "${SCRIPT}" "$@"
}

# Build a PATH dir holding only the binaries the runner needs up to and during
# its own tool guards, deliberately omitting the one named in $1. Echoes the
# dir path.
make_guard_bin() {
  local -r omitted="$1"
  local -r bin_dir="${BATS_TEST_TMPDIR}/guard-bin-no-${omitted}"
  mkdir --parents "${bin_dir}"
  local tool tool_path
  # bash: /usr/bin/env resolves the shebang through PATH. git: repo-root lookup.
  # date: log::log timestamps. awk + sed: path::remove. nproc: the --jobs count.
  # flock + parallel: what `bats --jobs` needs, and what the runner guards on.
  for tool in bash git date awk sed nproc flock parallel; do
    if [[ "${tool}" == "${omitted}" ]]; then
      continue
    fi
    tool_path="$(commands::executable_path "${tool}")"
    ln --symbolic "${tool_path}" "${bin_dir}/${tool}"
  done
  # bats is the recording stub, never a real binary. No guard test reaches the
  # point of running it — every one of them dies on an earlier guard.
  if [[ "${omitted}" != 'bats' ]]; then
    write_bats_stub "${bin_dir}" ''
  fi
  printf '%s\n' "${bin_dir}"
}

@test "dies when bats is not on PATH" {
  local bin_dir
  bin_dir="$(make_guard_bin 'bats')"
  run_in_fake_repo_with_path "${bin_dir}"
  assert_failure
  assert_output --partial 'bats not found on PATH'
  assert_output --partial './.ci/in-devshell ./run-tests'
  assert_output --partial 'just test'
}

@test "dies when flock is not on PATH" {
  local bin_dir
  bin_dir="$(make_guard_bin 'flock')"
  run_in_fake_repo_with_path "${bin_dir}"
  assert_failure
  assert_output --partial 'flock not found on PATH'
}

@test "no-arg invocation runs the three default suites in parallel" {
  install_bats_stub
  run_in_fake_repo
  assert_success
  local recorded
  recorded="$(cat "${ARGS_LOG}")"
  [[ "${recorded}" == *'--jobs'* ]]
  [[ "${recorded}" == *'--recursive'* ]]
  [[ "${recorded}" == *'--print-output-on-failure'* ]]
  [[ "${recorded}" == *"${FAKE_REPO}/test/functions"* ]]
  [[ "${recorded}" == *"${FAKE_REPO}/test/ci"* ]]
  [[ "${recorded}" == *"${FAKE_REPO}/test/root"* ]]
}

@test "arguments are forwarded verbatim without the default targets" {
  install_bats_stub
  run_in_fake_repo --filter 'is_blank' 'test/functions/strings.bats'
  assert_success
  local recorded
  recorded="$(cat "${ARGS_LOG}")"
  assert_equal "${recorded}" "--filter is_blank test/functions/strings.bats"
  [[ "${recorded}" != *'--jobs'* ]]
  [[ "${recorded}" != *"${FAKE_REPO}/test/functions"* ]]
}

@test "dies when GNU parallel is unavailable" {
  local bin_dir
  bin_dir="$(make_guard_bin 'parallel')"
  run_in_fake_repo_with_path "${bin_dir}"
  assert_failure
  assert_output --partial 'GNU parallel not found'
}

@test "tripwire: fails when the suite mutates the repo config" {
  # Stub bats writes into the surrounding fixture repo's config, simulating a
  # fixture escape, and exits 0 as if all tests passed.
  # shellcheck disable=SC2016 # single quotes are deliberate: the snippet is evaluated by the stub, not here
  make_recording_bats_stub_with_body 'git config --file "$(git rev-parse --path-format=absolute --git-path config)" bats.escaped true'
  run_in_fake_repo
  assert_failure
  assert_output --partial 'mutated the real repo'
}

@test "tripwire: fails when the suite moves HEAD" {
  make_recording_bats_stub_with_body 'git commit --quiet --allow-empty --message stray'
  run_in_fake_repo
  assert_failure
  assert_output --partial 'mutated the real repo'
}

@test "tripwire: silent on a clean green run" {
  make_recording_bats_stub_with_body ''
  run_in_fake_repo
  assert_success
  refute_output --partial 'mutated the real repo'
}

@test "tripwire: a red suite still reports the bats exit, not the tripwire" {
  make_recording_bats_stub_with_body 'exit 1'
  run_in_fake_repo
  assert_failure
  refute_output --partial 'mutated the real repo'
}
