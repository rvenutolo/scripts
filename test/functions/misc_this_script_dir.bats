#!/usr/bin/env bats

setup() {
  load '../test_helper/common'
}

# Helper: write an executable tmp script at the given path that sources args.bash
# + misc.bash, then calls misc::this_script_dir with the given trailing args (if any).
# $1 = absolute script path
# $2 = optional extra args appended to the misc::this_script_dir call (default: none)
write_caller_script() {
  local -r path="$1"
  local -r extra_args="${2:-}"
  mkdir --parents -- "$(dirname -- "${path}")"
  cat > "${path}" << EOF
#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
source '${SCRIPTS_DIR}/functions/log.bash'
# shellcheck disable=SC1091
source '${SCRIPTS_DIR}/functions/args.bash'
# shellcheck disable=SC1091
source '${SCRIPTS_DIR}/functions/misc.bash'
misc::this_script_dir ${extra_args}
EOF
  chmod +x "${path}"
}

@test "this_script_dir: returns directory of caller script" {
  local -r dir="${BATS_TEST_TMPDIR}/scripts"
  local -r script="${dir}/caller.sh"
  write_caller_script "${script}"
  run "${script}"
  assert_success
  assert_output "${dir}"
}

@test "this_script_dir: returns nested subdirectory of caller script" {
  local -r dir="${BATS_TEST_TMPDIR}/a/b/c"
  local -r script="${dir}/caller.sh"
  write_caller_script "${script}"
  run "${script}"
  assert_success
  assert_output "${dir}"
}

@test "this_script_dir: works when caller invoked via relative path" {
  local -r dir="${BATS_TEST_TMPDIR}/rel"
  local -r script="${dir}/caller.sh"
  write_caller_script "${script}"
  run bash -c "cd '${BATS_TEST_TMPDIR}' && rel/caller.sh"
  assert_success
  assert_output "${dir}"
}

@test "this_script_dir: works when caller invoked via symlink" {
  local -r real_dir="${BATS_TEST_TMPDIR}/real"
  local -r real_script="${real_dir}/caller.sh"
  local -r link_dir="${BATS_TEST_TMPDIR}/link_dir"
  write_caller_script "${real_script}"
  ln --symbolic -- "${real_dir}" "${link_dir}"
  run "${link_dir}/caller.sh"
  assert_success
  # `pwd` (default -L) preserves the symlink, so we expect the link path,
  # not the real path. This locks in the documented contract.
  assert_output "${link_dir}"
}

@test "this_script_dir: dies with args" {
  local -r dir="${BATS_TEST_TMPDIR}/scripts"
  local -r script="${dir}/caller.sh"
  write_caller_script "${script}" "extra"
  run "${script}"
  assert_failure
  assert_output --partial 'Expected no arguments'
}
