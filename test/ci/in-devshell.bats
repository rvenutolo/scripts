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
  load '../test_helper/devshell_nix'
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
  devshell_nix::setup
  STARTED="${BATS_TEST_TMPDIR}/started-pids"
  : > "${STARTED}"
}

# A case that fails midway must not leave a process it started running. A case
# records each pid it starts in the STARTED file and drops it once it has seen
# the process end: the kernel may hand that pid to an unrelated process, which a
# KILL here would then hit. A file, not an array: each case runs in a subshell of
# its own, so an array it extends would not reach teardown.
teardown() {
  local pid
  while IFS= read -r pid; do
    kill -s KILL "${pid}" 2> '/dev/null' || true
  done < "${STARTED}"
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
  TMPDIR
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

# Run the wrapper from a cwd inside the fixture repo, so a wrapper that took its
# flake from the cwd would show it. GIT_CEILING_DIRECTORIES is unset: common.bash
# sets it to the repo root, which stops git from climbing from .ci/ up to the
# root the wrapper resolves. TMPDIR is the scratch directory the case made.
run_wrapper() {
  cd "${REPO}" || return 1
  run env --unset=GIT_CEILING_DIRECTORIES TMPDIR="${NIX_SCRATCH}" "${WRAPPER}" "$@"
}

# The wrapper outside the devShell boundary, for the cases that watch it end:
# TMPDIR is $1, stdin is /dev/null.
# $1 = the TMPDIR the caller hands the wrapper, $@ = the command to wrap
wrap() {
  local -r tmpdir="$1"
  shift
  env --unset=GIT_CEILING_DIRECTORIES TMPDIR="${tmpdir}" "${WRAPPER}" "$@" < '/dev/null'
}

# How long a case waits for a process to start or end, in tenths of a second.
readonly WAIT_TICKS=300

# Record a pid this case started, for teardown. $1 = pid
remember_pid() {
  printf '%s\n' "$1" >> "${STARTED}"
}

# Drop a pid from the STARTED file once its process is known to have ended.
# $1 = pid
forget_pid() {
  local -a kept=()
  local pid
  while IFS= read -r pid; do
    [[ "${pid}" == "$1" ]] || kept+=("${pid}")
  done < "${STARTED}"
  if ((${#kept[@]} > 0)); then
    printf '%s\n' "${kept[@]}" > "${STARTED}"
  else
    : > "${STARTED}"
  fi
}

# Poll until a file exists and is non-empty. $1 = path
wait_for_file() {
  local ticks=0
  while [[ ! -s "$1" ]]; do
    ((++ticks > WAIT_TICKS)) && return 1
    sleep 0.1
  done
}

# Poll until a pid stops answering `kill -0`, then forget it. $1 = pid
wait_for_exit() {
  local ticks=0
  while kill -0 "$1" 2> '/dev/null'; do
    ((++ticks > WAIT_TICKS)) && return 1
    sleep 0.1
  done
  forget_pid "$1"
}

# Fail unless a recorded command has ended; then forget its pid. $1 = pid
assert_gone() {
  if kill -0 "$1" 2> '/dev/null'; then
    fail "the command (pid $1) is still running"
  fi
  forget_pid "$1"
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

@test "the flake reference is the repo the wrapper lives in, not the caller's cwd repo" {
  stub_nix
  run_wrapper echo hello
  assert_success
  run cli_shim::calls 'nix'
  assert_output --partial "develop ${REPO_REAL} --ignore-environment"
  refute_output --partial "develop ${REPO} "
}

@test "with GIT_DIR set, as git sets it for hooks, the flake is still the wrapper's repo" {
  # With GIT_DIR set and no GIT_WORK_TREE, `git rev-parse --show-toplevel`
  # answers with the directory it runs in, here .ci/.
  local git_dir
  git_dir="$(git -C "${REPO_DIR}" rev-parse --absolute-git-dir)"
  devshell_nix::install_recorder 0
  cd "${REPO}" || return 1
  PATH="${NIX_STUB_DIR}:${PATH}" run env --unset=GIT_CEILING_DIRECTORIES GIT_DIR="${git_dir}" \
    TMPDIR="${NIX_SCRATCH}" "${WRAPPER}" true
  assert_success
  devshell_nix::assert_reran true
}

@test "forwards the command and its arguments verbatim after --command" {
  stub_nix
  run_wrapper echo hello 'two words' --flag
  assert_success
  run cli_shim::calls 'nix'
  assert_output --partial '--command echo hello two words --flag'
}

@test "exports SCRIPTS_DIR as <wrapper repo>/scripts and the IN_DEVSHELL sentinel" {
  stub_nix_reporting_env
  run_wrapper echo hello
  assert_success
  assert_output --partial "SCRIPTS_DIR=${REPO_REAL}/scripts"
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

@test "dies when the wrapper itself is not inside a git repo, whatever the cwd" {
  stub_nix
  local -r loose="${TMP_ROOT}/loose/.ci"
  mkdir --parents -- "${loose}"
  cp -- "${WRAPPER}" "${loose}/in-devshell"
  cd "${REPO}" || return 1
  run --separate-stderr env TMPDIR="${NIX_SCRATCH}" "${loose}/in-devshell" echo hello
  assert_failure 1
  assert_stderr --partial 'not a git repo'
  assert [ ! -e "${BATS_TEST_TMPDIR}/nix.calls" ]
}

@test "a wrapped true succeeds and leaves the caller's TMPDIR empty" {
  devshell_nix::install_emulator
  cd "${REPO}" || return 1
  PATH="${NIX_STUB_DIR}:${PATH}" run wrap "${NIX_SCRATCH}" true
  assert_success
  devshell_nix::assert_scratch_empty
}

@test "the command's exit status is the wrapper's" {
  devshell_nix::install_emulator
  cd "${REPO}" || return 1
  PATH="${NIX_STUB_DIR}:${PATH}" run wrap "${NIX_SCRATCH}" sh -c 'exit 3'
  assert_failure 3
  devshell_nix::assert_scratch_empty
}

@test "the command sees a private TMPDIR inside the caller's" {
  devshell_nix::install_emulator
  local scratch_real
  scratch_real="$(readlink --canonicalize -- "${NIX_SCRATCH}")"
  cd "${REPO}" || return 1
  PATH="${NIX_STUB_DIR}:${PATH}" run wrap "${NIX_SCRATCH}" sh -c 'printf "TMPDIR=%s\n" "${TMPDIR}"'
  assert_success
  assert_line --regexp "^TMPDIR=${scratch_real}/in-devshell\.[^/]+/"
  devshell_nix::assert_scratch_empty
}

@test "a relative caller TMPDIR that exists is made absolute" {
  devshell_nix::install_emulator
  local scratch_real
  scratch_real="$(readlink --canonicalize -- "${NIX_SCRATCH}")"
  cd "${BATS_TEST_TMPDIR}" || return 1
  PATH="${NIX_STUB_DIR}:${PATH}" run wrap 'scratch' sh -c 'printf "TMPDIR=%s\n" "${TMPDIR}"'
  assert_success
  assert_line --regexp "^TMPDIR=${scratch_real}/in-devshell\.[^/]+/"
  devshell_nix::assert_scratch_empty
}

@test "a caller TMPDIR naming no directory fails with one line and creates nothing" {
  devshell_nix::install_emulator
  local value
  cd "${BATS_TEST_TMPDIR}" || return 1
  for value in "${BATS_TEST_TMPDIR}/does-not-exist" 'does-not-exist-relative'; do
    PATH="${NIX_STUB_DIR}:${PATH}" run wrap "${value}" true
    assert_failure 1
    assert_equal "${#lines[@]}" 1
    assert_output --partial "TMPDIR ${value} names no directory"
    assert [ ! -e "${value}" ]
  done
  assert [ ! -e "${NIX_ARGS_FILE}" ]
}

@test "a caller TMPDIR that is a plain file fails with one line and creates nothing" {
  devshell_nix::install_emulator
  local -r plain="${BATS_TEST_TMPDIR}/plain-file"
  : > "${plain}"
  cd "${BATS_TEST_TMPDIR}" || return 1
  PATH="${NIX_STUB_DIR}:${PATH}" run wrap "${plain}" true
  assert_failure 1
  assert_equal "${#lines[@]}" 1
  assert_output --partial "TMPDIR ${plain} names no directory"
  assert [ -f "${plain}" ]
  assert [ ! -s "${plain}" ]
  assert [ ! -e "${NIX_ARGS_FILE}" ]
  devshell_nix::assert_scratch_empty
}

@test "the devShell is the wrapper's own repo when the caller's cwd is outside any repo" {
  devshell_nix::install_emulator
  mkdir -- "${BATS_TEST_TMPDIR}/elsewhere"
  cd "${BATS_TEST_TMPDIR}/elsewhere" || return 1
  PATH="${NIX_STUB_DIR}:${PATH}" run wrap "${NIX_SCRATCH}" \
    sh -c 'printf "IN_DEVSHELL=%s\n" "${IN_DEVSHELL:-}"; exit 4'
  assert_failure 4
  assert_line 'IN_DEVSHELL=1'
  devshell_nix::assert_reran sh -c 'printf "IN_DEVSHELL=%s\n" "${IN_DEVSHELL:-}"; exit 4'
  devshell_nix::assert_scratch_empty
}

# The signal cases start the wrapper as a plain background command, not through
# `wrap`: bash forks once and env execs the wrapper, so `$!` is the wrapper's own
# pid. A function run in the background would put a subshell in between. Every
# descriptor is redirected, fd 3 included: bats waits for fd 3 to close, so a job
# holding it would stall the suite. Signals go only to processes the case
# started, by recorded pid or by the process group of a job it started. The INT
# cases reset SIGINT to its default with `env --default-signal=INT`: `bats --jobs`
# starts each file as a background job, which inherits SIGINT ignored, and a
# signal ignored on entry to a shell cannot be trapped or restored there, so
# without the reset neither the wrapper nor the command would see a Ctrl-C.

@test "SIGINT to the process group ends the command and leaves TMPDIR empty" {
  devshell_nix::install_emulator
  local wrapper_pid cmd_pid rc=0
  cd "${REPO}" || return 1
  # Job control gives the background wrapper a process group of its own, so the
  # signal below reaches only the processes this case started.
  set -m
  PATH="${NIX_STUB_DIR}:${PATH}" env --default-signal=INT --unset=GIT_CEILING_DIRECTORIES \
    TMPDIR="${NIX_SCRATCH}" "${WRAPPER}" \
    sh -c 'echo $$ > "$1"; exec sleep 300' sh "${BATS_TEST_TMPDIR}/cmd.pid" \
    < '/dev/null' > "${BATS_TEST_TMPDIR}/out" 2>&1 3>&- &
  wrapper_pid="$!"
  set +m
  remember_pid "${wrapper_pid}"
  wait_for_file "${BATS_TEST_TMPDIR}/cmd.pid" \
    || fail "the command never started: $(< "${BATS_TEST_TMPDIR}/out")"
  cmd_pid="$(< "${BATS_TEST_TMPDIR}/cmd.pid")"
  remember_pid "${cmd_pid}"
  kill -s INT -- "-${wrapper_pid}"
  wait "${wrapper_pid}" || rc="$?"
  forget_pid "${wrapper_pid}"
  assert_equal "${rc}" 130
  assert_gone "${cmd_pid}"
  devshell_nix::assert_scratch_empty
}

@test "a command that traps INT outlives a Ctrl-C and keeps its TMPDIR until it exits" {
  devshell_nix::install_emulator
  local wrapper_pid cmd_pid
  cd "${REPO}" || return 1
  set -m
  PATH="${NIX_STUB_DIR}:${PATH}" env --default-signal=INT --unset=GIT_CEILING_DIRECTORIES \
    TMPDIR="${NIX_SCRATCH}" "${WRAPPER}" \
    sh -c 'trap "echo caught > \"\$2\"" INT; echo $$ > "$1"; while [ ! -e "$3" ]; do sleep 0.1; done' \
    sh "${BATS_TEST_TMPDIR}/cmd.pid" "${BATS_TEST_TMPDIR}/caught" "${BATS_TEST_TMPDIR}/release" \
    < '/dev/null' > "${BATS_TEST_TMPDIR}/out" 2>&1 3>&- &
  wrapper_pid="$!"
  set +m
  remember_pid "${wrapper_pid}"
  wait_for_file "${BATS_TEST_TMPDIR}/cmd.pid" \
    || fail "the command never started: $(< "${BATS_TEST_TMPDIR}/out")"
  cmd_pid="$(< "${BATS_TEST_TMPDIR}/cmd.pid")"
  remember_pid "${cmd_pid}"
  kill -s INT -- "-${wrapper_pid}"
  wait_for_file "${BATS_TEST_TMPDIR}/caught" || fail 'the command never saw the signal'
  kill -0 "${wrapper_pid}" 2> '/dev/null' || fail 'the wrapper died on the first INT'
  kill -0 "${cmd_pid}" 2> '/dev/null' || fail 'the command died on the first INT'
  if [[ -z "$(find "${NIX_SCRATCH}" -mindepth 1 -maxdepth 1)" ]]; then
    fail 'the private TMPDIR was removed under a running command'
  fi
  : > "${BATS_TEST_TMPDIR}/release"
  wait_for_exit "${wrapper_pid}" || fail 'the wrapper did not end after the command did'
  assert_gone "${cmd_pid}"
  devshell_nix::assert_scratch_empty
}

@test "SIGTERM to the wrapper alone gives 143 and leaves TMPDIR empty" {
  devshell_nix::install_emulator
  local wrapper_pid cmd_pid rc=0
  cd "${REPO}" || return 1
  PATH="${NIX_STUB_DIR}:${PATH}" env --unset=GIT_CEILING_DIRECTORIES TMPDIR="${NIX_SCRATCH}" "${WRAPPER}" \
    sh -c 'echo $$ > "$1"; exec sleep 300' sh "${BATS_TEST_TMPDIR}/cmd.pid" \
    < '/dev/null' > "${BATS_TEST_TMPDIR}/out" 2>&1 3>&- &
  wrapper_pid="$!"
  remember_pid "${wrapper_pid}"
  wait_for_file "${BATS_TEST_TMPDIR}/cmd.pid" \
    || fail "the command never started: $(< "${BATS_TEST_TMPDIR}/out")"
  cmd_pid="$(< "${BATS_TEST_TMPDIR}/cmd.pid")"
  remember_pid "${cmd_pid}"
  kill -s TERM "${wrapper_pid}"
  wait "${wrapper_pid}" || rc="$?"
  forget_pid "${wrapper_pid}"
  assert_equal "${rc}" 143
  assert_gone "${cmd_pid}"
  devshell_nix::assert_scratch_empty
}

@test "a command that handles a forwarded SIGTERM reports its own status" {
  devshell_nix::install_emulator
  local wrapper_pid cmd_pid rc=0
  cd "${REPO}" || return 1
  PATH="${NIX_STUB_DIR}:${PATH}" env --unset=GIT_CEILING_DIRECTORIES TMPDIR="${NIX_SCRATCH}" "${WRAPPER}" \
    sh -c 'trap "kill \$! 2> /dev/null; exit 0" TERM; echo $$ > "$1"; sleep 300 & wait' \
    sh "${BATS_TEST_TMPDIR}/cmd.pid" \
    < '/dev/null' > "${BATS_TEST_TMPDIR}/out" 2>&1 3>&- &
  wrapper_pid="$!"
  remember_pid "${wrapper_pid}"
  wait_for_file "${BATS_TEST_TMPDIR}/cmd.pid" \
    || fail "the command never started: $(< "${BATS_TEST_TMPDIR}/out")"
  cmd_pid="$(< "${BATS_TEST_TMPDIR}/cmd.pid")"
  remember_pid "${cmd_pid}"
  kill -s TERM "${wrapper_pid}"
  wait "${wrapper_pid}" || rc="$?"
  forget_pid "${wrapper_pid}"
  assert_equal "${rc}" 0
  assert_gone "${cmd_pid}"
  devshell_nix::assert_scratch_empty
}
