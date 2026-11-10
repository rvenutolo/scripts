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
  FAKE_REPO="${BATS_TEST_TMPDIR}/fake-repo"
  mkdir -p "${FAKE_REPO}"
  # pwd -P so the path matches the canonical path the runner derives its root from;
  # BATS_TEST_TMPDIR can sit under a symlinked TMPDIR.
  FAKE_REPO="$(cd "${FAKE_REPO}" && pwd -P)"
  # The runner takes its repo root from its own path, so the fixture cases run a
  # copy at the root of the fake repo, the same depth as the original.
  SCRIPT="${FAKE_REPO}/run-tests"
  cp -- "${REPO_DIR}/run-tests" "${SCRIPT}"
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
  load '../test_helper/devshell_nix'
  # The stub devShell's PATH starts with the recording bats, so a re-run reaches
  # it rather than the real one.
  PATH="${STUB_BIN}:${PATH}" devshell_nix::setup
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

# Give the fake repo a one-suite .ci/test-suites, which a no-argument run reads.
write_suites_fixture() {
  mkdir --parents "${FAKE_REPO}/.ci"
  printf '%s\n' 'test/alpha' > "${FAKE_REPO}/.ci/test-suites"
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
  # bash: /usr/bin/env resolves the shebang through PATH. readlink: the runner's
  # own path. git: repo state. date: log::log timestamps. awk + sed: path::remove. nproc: the --jobs count.
  # flock + parallel: what `bats --jobs` needs, and what the runner guards on.
  for tool in bash readlink git date awk sed nproc flock parallel; do
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
  assert_output --partial "'./run-tests'"
  assert_output --partial 'just test'
}

@test "dies when flock is not on PATH" {
  local bin_dir
  bin_dir="$(make_guard_bin 'flock')"
  run_in_fake_repo_with_path "${bin_dir}"
  assert_failure
  assert_output --partial 'flock not found on PATH'
}

@test "no-arg invocation runs the suites listed in .ci/test-suites" {
  install_bats_stub
  mkdir --parents "${FAKE_REPO}/.ci"
  printf '%s\n' '# comment lines and blank lines are skipped' '' 'test/alpha' 'test/beta' \
    > "${FAKE_REPO}/.ci/test-suites"
  run_in_fake_repo
  assert_success
  local recorded
  recorded="$(cat "${ARGS_LOG}")"
  [[ "${recorded}" == *"${FAKE_REPO}/test/alpha"* ]]
  [[ "${recorded}" == *"${FAKE_REPO}/test/beta"* ]]
  [[ "${recorded}" != *'comment'* ]]
  [[ "${recorded}" != *"${FAKE_REPO}/test/shims"* ]]
}

@test "dies when .ci/test-suites is missing" {
  install_bats_stub
  run_in_fake_repo
  assert_failure 1
  assert_output --partial "${FAKE_REPO}/.ci/test-suites"
}

@test "no-arg invocation runs the four shipped default suites in parallel" {
  install_bats_stub
  mkdir --parents "${FAKE_REPO}/.ci"
  cp -- "${REPO_DIR}/.ci/test-suites" "${FAKE_REPO}/.ci/test-suites"
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
  [[ "${recorded}" == *"${FAKE_REPO}/test/shims"* ]]
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

@test "CI shard flags plus explicit files are forwarded without the default suites" {
  install_bats_stub
  # The shipped suites file is present, so a leak of the default roots would show.
  mkdir --parents "${FAKE_REPO}/.ci"
  cp -- "${REPO_DIR}/.ci/test-suites" "${FAKE_REPO}/.ci/test-suites"
  run_in_fake_repo --jobs 4 --print-output-on-failure --report-formatter junit --output 'junit-out' \
    'test/ci/a.bats' 'test/functions/b.bats'
  assert_success
  local recorded
  recorded="$(cat "${ARGS_LOG}")"
  assert_equal "${recorded}" \
    '--jobs 4 --print-output-on-failure --report-formatter junit --output junit-out test/ci/a.bats test/functions/b.bats'
  [[ "${recorded}" != *'--recursive'* ]]
  local suite
  for suite in functions ci root shims; do
    [[ "${recorded}" != *"${FAKE_REPO}/test/${suite}"* ]]
  done
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
  write_suites_fixture
  run_in_fake_repo
  assert_failure
  assert_output --partial 'mutated the real repo'
}

@test "tripwire: fails when the suite moves HEAD" {
  make_recording_bats_stub_with_body 'git commit --quiet --allow-empty --message stray'
  write_suites_fixture
  run_in_fake_repo
  assert_failure
  assert_output --partial 'mutated the real repo'
}

@test "tripwire: silent on a clean green run" {
  make_recording_bats_stub_with_body ''
  write_suites_fixture
  run_in_fake_repo
  assert_success
  refute_output --partial 'mutated the real repo'
}

@test "tripwire: a red suite still reports the bats exit, not the tripwire" {
  make_recording_bats_stub_with_body 'exit 1'
  write_suites_fixture
  run_in_fake_repo
  assert_failure
  refute_output --partial 'mutated the real repo'
}

# The self-wrap cases: a direct run from a shell outside the devShell re-runs the
# script through .ci/in-devshell. devshell_nix::run_outside starts it the way such
# a shell would, against the stub nix (see devshell_nix.bash).

@test "self-wrap: a direct run re-runs itself inside the devShell, with the host PATH gone" {
  devshell_nix::install_emulator
  install_bats_stub
  cd "${FAKE_REPO}" || return 1
  run devshell_nix::run_outside "${REPO_DIR}/run-tests" --filter 'x y'
  assert_success
  assert_equal "$(cat "${ARGS_LOG}")" '--filter x y'
  devshell_nix::assert_reran "${REPO_REAL}/run-tests" --filter 'x y'
  devshell_nix::assert_in_devshell
  devshell_nix::assert_scratch_empty
}

@test "self-wrap: arguments and exit status survive the re-run" {
  devshell_nix::install_recorder 7
  cd "${FAKE_REPO}" || return 1
  run devshell_nix::run_outside "${REPO_DIR}/run-tests" 'a b' '' '*'
  assert_failure 7
  devshell_nix::assert_reran "${REPO_REAL}/run-tests" 'a b' '' '*'
  devshell_nix::assert_scratch_empty
}

@test "self-wrap: a run through a symlink from the repo root hands itself to the devShell" {
  devshell_nix::install_recorder 5
  ln --symbolic -- "${REPO_DIR}/run-tests" "${BATS_TEST_TMPDIR}/link"
  cd "${REPO_DIR}" || return 1
  run devshell_nix::run_outside "${BATS_TEST_TMPDIR}/link" 'x'
  assert_failure 5
  devshell_nix::assert_reran "${REPO_REAL}/run-tests" 'x'
  devshell_nix::assert_in_devshell
  devshell_nix::assert_scratch_empty
}

@test "self-wrap: a run through a symlink from outside any repo hands itself to the devShell" {
  devshell_nix::install_recorder 6
  mkdir -- "${BATS_TEST_TMPDIR}/elsewhere"
  ln --symbolic -- "${REPO_DIR}/run-tests" "${BATS_TEST_TMPDIR}/elsewhere/link"
  cd "${BATS_TEST_TMPDIR}/elsewhere" || return 1
  run devshell_nix::run_outside "${BATS_TEST_TMPDIR}/elsewhere/link" 'y'
  assert_failure 6
  devshell_nix::assert_reran "${REPO_REAL}/run-tests" 'y'
  devshell_nix::assert_in_devshell
  devshell_nix::assert_scratch_empty
}

@test "self-wrap: with IN_DEVSHELL already set there is no re-run" {
  devshell_nix::install_recorder 42
  install_bats_stub
  cd "${FAKE_REPO}" || return 1
  run env IN_DEVSHELL=1 PATH="${HOST_DIR}:${NIX_STUB_DIR}:${STUB_BIN}:${PATH}" TMPDIR="${NIX_SCRATCH}" \
    "${REPO_DIR}/run-tests" --filter 'x y'
  assert_success
  assert_equal "$(cat "${ARGS_LOG}")" '--filter x y'
  assert [ ! -e "${NIX_ARGS_FILE}" ]
}
