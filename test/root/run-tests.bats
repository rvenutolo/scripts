bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # Sourced for make_no_parallel_bin, which resolves real binary paths the same
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
}

# Install a stub at ${FAKE_REPO}/test/bats/bin/bats that records its argv.
# This is what prevents the test from invoking the real bats binary.
install_bats_stub() {
  mkdir -p "${FAKE_REPO}/test/bats/bin"
  cat > "${FAKE_REPO}/test/bats/bin/bats" << EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "${ARGS_LOG}"
exit 0
EOF
  chmod +x "${FAKE_REPO}/test/bats/bin/bats"
}

# Like install_bats_stub, but runs the given body line(s) before exiting 0 —
# used to simulate the suite mutating the surrounding fixture repo (#248).
make_recording_bats_stub_with_body() {
  local -r body="$1"
  mkdir -p "${FAKE_REPO}/test/bats/bin"
  cat > "${FAKE_REPO}/test/bats/bin/bats" << EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "${ARGS_LOG}"
${body}
exit 0
EOF
  chmod +x "${FAKE_REPO}/test/bats/bin/bats"
}

run_in_fake_repo() {
  cd "${FAKE_REPO}" || return 1
  run "${SCRIPT}" "$@"
}

# Build a PATH dir holding only the binaries the runner needs before it checks
# for parallel, deliberately omitting parallel itself. Echoes the dir path.
make_no_parallel_bin() {
  local -r bin_dir="${BATS_TEST_TMPDIR}/no-parallel-bin"
  mkdir -p "${bin_dir}"
  local tool tool_path
  # bash: /usr/bin/env resolves the shebang through PATH. git: repo-root lookup.
  # date: log::log timestamps. awk + sed: path::remove. nproc: the --jobs count.
  for tool in bash git date awk sed nproc; do
    tool_path="$(commands::executable_path "${tool}")"
    ln --symbolic "${tool_path}" "${bin_dir}/${tool}"
  done
  printf '%s\n' "${bin_dir}"
}

@test "dies with the submodule hint when bats is missing" {
  run_in_fake_repo
  assert_failure
  assert_output --partial 'git submodule update'
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
  install_bats_stub
  local bin_dir
  bin_dir="$(make_no_parallel_bin)"
  cd "${FAKE_REPO}" || return 1
  # --unset=BASH_ENV: a child bash would otherwise re-source the user's
  # interactive ~/.bashrc, restoring the real PATH and putting parallel back.
  run env --unset=BASH_ENV PATH="${bin_dir}" "${SCRIPT}"
  assert_failure
  assert_output --partial 'GNU parallel not found'
}

@test "tripwire: fails when the suite mutates the repo config" {
  # Stub bats writes into the surrounding fixture repo's config, simulating a
  # fixture escape (#248), and exits 0 as if all tests passed.
  # shellcheck disable=SC2016 # single quotes are deliberate: the snippet is evaluated by the stub, not here
  make_recording_bats_stub_with_body 'git config --file "$(git rev-parse --path-format=absolute --git-path config)" bats.escaped true'
  run_in_fake_repo
  assert_failure
  assert_output --partial '#248'
}

@test "tripwire: fails when the suite moves HEAD" {
  make_recording_bats_stub_with_body 'git commit --quiet --allow-empty --message stray'
  run_in_fake_repo
  assert_failure
  assert_output --partial '#248'
}

@test "tripwire: silent on a clean green run" {
  make_recording_bats_stub_with_body ''
  run_in_fake_repo
  assert_success
  refute_output --partial '#248'
}

@test "tripwire: a red suite still reports the bats exit, not the tripwire" {
  make_recording_bats_stub_with_body 'exit 1'
  run_in_fake_repo
  assert_failure
  refute_output --partial '#248'
}
