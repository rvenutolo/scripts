#!/usr/bin/env bash

# Per-test stand-in for `nix develop`, for the suites that drive .ci/in-devshell
# and the gate scripts that re-run themselves through it. No test may run the
# real nix (see common.bash), so the stub models the parts of `nix develop` the
# wrapper depends on:
#
#   - it records its argv, one argument per line, to NIX_ARGS_FILE;
#   - it makes a nix-shell.XXXXXX directory under the TMPDIR it is handed and
#     points TMPDIR there, and never removes it, as the real one does;
#   - with --ignore-environment it passes on only the --keep variables that are
#     set, otherwise the whole caller environment, and puts NIX_DEVSHELL_PATH
#     first on PATH (alone, under --ignore-environment);
#   - it records the environment the command gets to NIX_ENV_FILE.
#
# The recorder then exits with a fixed status; the emulator execs the command,
# so the wrapper's child becomes the command itself.
#
# devshell_nix::setup sets:
#   NIX_STUB_DIR     the directory holding the stub nix and the host tools a run
#                    outside the devShell is given
#   HOST_DIR         an empty directory standing in for a host PATH entry
#   NIX_SCRATCH      an empty directory handed to the wrapper as its TMPDIR
#   NIX_ARGS_FILE    where the stub records its argv
#   NIX_ENV_FILE     where the stub records the command's environment
#   NIX_DEVSHELL_PATH the PATH the stub's devShell has: the suite's own PATH
#   REPO_REAL        REPO_DIR with symlinks resolved, as the wrapper spells it

# Creates the directories and links the host tools the self-wrap block, the
# wrapper and the stub use. Call from setup().
function devshell_nix::setup() {
  NIX_STUB_DIR="${BATS_TEST_TMPDIR}/nix-stub"
  HOST_DIR="${BATS_TEST_TMPDIR}/host"
  NIX_SCRATCH="${BATS_TEST_TMPDIR}/scratch"
  NIX_ARGS_FILE="${BATS_TEST_TMPDIR}/nix-args"
  NIX_ENV_FILE="${BATS_TEST_TMPDIR}/nix-env"
  NIX_DEVSHELL_PATH="${PATH}"
  REPO_REAL="$(readlink --canonicalize -- "${REPO_DIR}")"
  mkdir --parents -- "${NIX_STUB_DIR}" "${HOST_DIR}" "${NIX_SCRATCH}"
  local tool tool_path
  for tool in bash date dirname env git mktemp printenv readlink rm; do
    tool_path="$(type -P "${tool}")"
    ln --symbolic -- "${tool_path}" "${NIX_STUB_DIR}/${tool}"
  done
}

# Writes the stub nix. $1 = mode (record or emulate), $2 = recorder exit status.
function devshell_nix::_write() {
  local -r mode="$1"
  local -r status="$2"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -euo pipefail\n'
    printf 'readonly MODE=%q STATUS=%q ARGS_FILE=%q ENV_FILE=%q DEVSHELL_PATH=%q\n' \
      "${mode}" "${status}" "${NIX_ARGS_FILE}" "${NIX_ENV_FILE}" "${NIX_DEVSHELL_PATH}"
    cat << 'EOF'
printf '%s\n' "$@" > "${ARGS_FILE}"
ignore='n'
keeps=()
while (($# > 0)); do
  case "$1" in
    --ignore-environment) ignore='y'; shift ;;
    --keep) keeps+=("$2"); shift 2 ;;
    --command) shift; break ;;
    *) shift ;;
  esac
done
nix_tmp="$(mktemp --directory --tmpdir="${TMPDIR:?the stub needs a TMPDIR the test made}" nix-shell.XXXXXX)"
env_args=()
if [[ "${ignore}" == 'y' ]]; then
  env_args+=(--ignore-environment)
  for name in ${keeps[@]+"${keeps[@]}"}; do
    if [[ -v "${name}" ]]; then
      env_args+=("${name}=${!name}")
    fi
  done
  env_args+=("PATH=${DEVSHELL_PATH}")
else
  env_args+=("PATH=${DEVSHELL_PATH}:${PATH}")
fi
env_args+=("TMPDIR=${nix_tmp}")
env "${env_args[@]}" "$(type -P printenv)" > "${ENV_FILE}"
if [[ "${MODE}" == 'record' ]]; then
  exit "${STATUS}"
fi
exec env "${env_args[@]}" "$@"
EOF
  } > "${NIX_STUB_DIR}/nix"
  chmod +x -- "${NIX_STUB_DIR}/nix"
}

# Installs the recording stub. $1 = the status it exits with (default 0).
function devshell_nix::install_recorder() {
  devshell_nix::_write 'record' "${1:-0}"
}

# Installs the emulating stub, which runs the command in the stub devShell.
function devshell_nix::install_emulator() {
  devshell_nix::_write 'emulate' 0
}

# Runs a command as a direct run from an interactive shell outside the devShell
# would: IN_DEVSHELL and SCRIPTS_DIR unset, HOST_DIR first on a PATH that holds
# only the stub nix and the host tools, NIX_SCRATCH as TMPDIR, stdin from
# /dev/null. Also unset: GIT_CEILING_DIRECTORIES, which common.bash sets to the
# repo root and which stops git from climbing from .ci/ up to the root the
# wrapper resolves, and the DEVSHELL_*_OVERRIDE seams common.bash sets, which
# put check-devshell-provides in fixture mode. A script that failed to re-run
# itself finds none of the tools it calls, so it stops instead of doing its work.
# $@ = the command and its arguments
function devshell_nix::run_outside() {
  env --unset=IN_DEVSHELL --unset=SCRIPTS_DIR --unset=GIT_CEILING_DIRECTORIES \
    --unset=DEVSHELL_PATH_OVERRIDE --unset=DEVSHELL_PACKAGES_OVERRIDE \
    PATH="${HOST_DIR}:${NIX_STUB_DIR}" TMPDIR="${NIX_SCRATCH}" "$@" < '/dev/null'
}

# Fails unless the stub was asked to enter REPO_DIR's devShell with the
# environment wiped and to run exactly the given command line.
# $@ = the expected command and its arguments
function devshell_nix::assert_reran() {
  if [[ ! -e "${NIX_ARGS_FILE}" ]]; then
    fail 'nix was never invoked: the script did not re-run itself through .ci/in-devshell'
  fi
  local -a got=()
  mapfile -t got < "${NIX_ARGS_FILE}"
  assert_equal "${got[0]}" 'develop'
  assert_equal "${got[1]}" "${REPO_REAL}"
  assert_equal "${got[2]}" '--ignore-environment'
  local index=0
  while ((index < ${#got[@]})) && [[ "${got[index]}" != '--command' ]]; do
    index=$((index + 1))
  done
  local -a command=("${got[@]:index+1}")
  local -a expected=("$@")
  assert_equal "${#command[@]}" "${#expected[@]}"
  local i
  for i in "${!expected[@]}"; do
    assert_equal "${command[i]}" "${expected[i]}"
  done
}

# Fails unless the command the stub ran had IN_DEVSHELL set and no HOST_DIR on
# its PATH.
function devshell_nix::assert_in_devshell() {
  if [[ ! -e "${NIX_ENV_FILE}" ]]; then
    fail 'nix was never invoked: the script did not re-run itself through .ci/in-devshell'
  fi
  local -a lines_seen=()
  mapfile -t lines_seen < "${NIX_ENV_FILE}"
  local line in_devshell='' path_value=''
  for line in "${lines_seen[@]}"; do
    case "${line}" in
      IN_DEVSHELL=*)
        in_devshell="${line#IN_DEVSHELL=}"
        ;;
      PATH=*)
        path_value="${line#PATH=}"
        ;;
    esac
  done
  assert_equal "${in_devshell}" '1'
  case ":${path_value}:" in
    *":${HOST_DIR}:"*)
      fail "the host PATH entry ${HOST_DIR} reached the devShell: ${path_value}"
      ;;
  esac
}

# Fails unless NIX_SCRATCH is empty, naming what was left in it.
function devshell_nix::assert_scratch_empty() {
  local left
  left="$(find "${NIX_SCRATCH}" -mindepth 1 -maxdepth 1 -printf '%f ')"
  if [[ -n "${left}" ]]; then
    fail "left behind in ${NIX_SCRATCH}: ${left}"
  fi
}
