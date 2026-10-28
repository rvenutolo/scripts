bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  INTERACTIVE="${REPO_DIR}/scripts/interactive"
  export XDG_CONFIG_HOME="${BATS_TEST_TMPDIR}/config"
  export WORK_PROJECTS_DIR="${BATS_TEST_TMPDIR}/work-projects"
  PERSONAL_DIR="${XDG_CONFIG_HOME}/claude/personal"
  WORK_DIR="${XDG_CONFIG_HOME}/claude/work"
  mkdir --parents "${PERSONAL_DIR}" "${WORK_DIR}" "${WORK_PROJECTS_DIR}/repo"
  unset CLAUDE_CONFIG_DIR
  # A stub `ccusage` that prints the config dir it was exec'd with, then its
  # argv. commands::executable_path strips only the repo's wrapper dirs, so the
  # wrapper resolves this stub as the real binary.
  path_shim::add 'ccusage' "$(
    cat << 'STUB'
#!/usr/bin/env bash
printf 'CLAUDE_CONFIG_DIR=%s\n' "${CLAUDE_CONFIG_DIR-<unset>}"
printf 'ARGS=%s\n' "$*"
STUB
  )"
}

# run_script <name> [args...] — BASH_ENV=SAFE_BASH_ENV so a child bash does not
# re-source ~/.bashrc and re-prepend the real PATH ahead of the stub.
run_script() {
  local -r name="$1"
  shift
  run env BASH_ENV="${SAFE_BASH_ENV}" "${INTERACTIVE}/${name}" "$@"
}

@test "ccusage: derives the personal profile outside WORK_PROJECTS_DIR" {
  cd "${BATS_TEST_TMPDIR}"
  run_script ccusage
  assert_success
  assert_line "CLAUDE_CONFIG_DIR=${PERSONAL_DIR}"
}

@test "ccusage: derives the work profile under WORK_PROJECTS_DIR" {
  cd "${WORK_PROJECTS_DIR}/repo"
  run_script ccusage
  assert_success
  assert_line "CLAUDE_CONFIG_DIR=${WORK_DIR}"
}

@test "ccusage: honors an already-set CLAUDE_CONFIG_DIR verbatim" {
  cd "${WORK_PROJECTS_DIR}/repo"
  CLAUDE_CONFIG_DIR="${BATS_TEST_TMPDIR}/explicit" run_script ccusage
  assert_success
  assert_line "CLAUDE_CONFIG_DIR=${BATS_TEST_TMPDIR}/explicit"
}

@test "ccusage: forwards arguments verbatim" {
  run_script ccusage monthly --json
  assert_success
  assert_line 'ARGS=monthly --json'
}

@test "ccusage: dies when the real ccusage is missing" {
  rm "${BATS_TEST_TMPDIR}/bin/ccusage"
  run env BASH_ENV="${SAFE_BASH_ENV}" PATH="${BATS_TEST_TMPDIR}/bin:/usr/bin:/bin" "${INTERACTIVE}/ccusage"
  assert_failure 1
  assert_output --partial 'ccusage executable not found'
}

@test "ccusage-personal: forces the personal profile over an inherited value" {
  cd "${WORK_PROJECTS_DIR}/repo"
  CLAUDE_CONFIG_DIR="${WORK_DIR}" run_script ccusage-personal daily
  assert_success
  assert_line "CLAUDE_CONFIG_DIR=${PERSONAL_DIR}"
  assert_line 'ARGS=daily'
}

@test "ccusage-work: forces the work profile over an inherited value" {
  cd "${BATS_TEST_TMPDIR}"
  CLAUDE_CONFIG_DIR="${PERSONAL_DIR}" run_script ccusage-work daily
  assert_success
  assert_line "CLAUDE_CONFIG_DIR=${WORK_DIR}"
  assert_line 'ARGS=daily'
}

@test "ccusage-all: joins every profile dir with commas, personal first" {
  CLAUDE_CONFIG_DIR="${BATS_TEST_TMPDIR}/explicit" run_script ccusage-all monthly
  assert_success
  assert_line "CLAUDE_CONFIG_DIR=${PERSONAL_DIR},${WORK_DIR}"
  assert_line 'ARGS=monthly'
}

@test "ccusage-all: uses only the profile dirs that exist" {
  rmdir "${WORK_DIR}"
  run_script ccusage-all
  assert_success
  assert_line "CLAUDE_CONFIG_DIR=${PERSONAL_DIR}"
}

@test "ccusage-all: dies when no profile dir exists" {
  rmdir "${PERSONAL_DIR}" "${WORK_DIR}"
  run_script ccusage-all
  assert_failure 1
  assert_output --partial 'No Claude profile config dirs found'
  refute_output --partial 'ARGS='
}
