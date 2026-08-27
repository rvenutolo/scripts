bats_require_minimum_version 1.5.0
setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  load '../test_helper/git_fixture'
  CHECK="${REPO_DIR}/.ci/check-inherit-errexit"
  FIXTURE_CI="${BATS_TEST_TMPDIR}/ci"
  FIXTURE_HOOKS="${BATS_TEST_TMPDIR}/hooks"
  FIXTURE_ROOT="${BATS_TEST_TMPDIR}/root"
  mkdir -p "${FIXTURE_CI}" "${FIXTURE_HOOKS}" "${FIXTURE_ROOT}"
  # The check resolves REPO_DIR via `git rev-parse --show-toplevel`, so it must run
  # with cwd inside a git repo or it exits 128 before any scan. common.bash leaves
  # cwd at BATS_TEST_TMPDIR, which is deliberately not a repo (fixture-escape
  # hardening), so give the check a throwaway fixture repo to resolve. Only
  # REPO_DIR resolution depends on it — the three scan roots come from the
  # overrides below.
  FIXTURE_REPO="${BATS_TEST_TMPDIR}/repo"
  git_fixture::init "${FIXTURE_REPO}"
  cd "${FIXTURE_REPO}" || return 1
  # An empty EXEMPT by default: the shipped entry names a real repo script that
  # does not exist in a fixture dir and would otherwise read as stale.
  export EXEMPT_OVERRIDE=''
  export CI_DIR_OVERRIDE="${FIXTURE_CI}"
  export HOOKS_DIR_OVERRIDE="${FIXTURE_HOOKS}"
  export ROOT_DIR_OVERRIDE="${FIXTURE_ROOT}"
}

# Write an executable fixture script whose body is the given lines.
write_script() {
  local -r path="$1"
  shift
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' "$@"
  } > "${path}"
  chmod +x "${path}"
}

# Write a compliant fixture script: strict mode, then the shopt, then a body.
write_compliant() {
  local -r path="$1"
  write_script "${path}" 'set -Eeuo pipefail' 'shopt -s inherit_errexit' "IFS=\$'\n\t'" 'echo hi'
}

@test "passes on a compliant .ci fixture" {
  write_compliant "${FIXTURE_CI}/clean"
  run "${CHECK}"
  assert_success
}

@test "passes on an empty scope" {
  run "${CHECK}"
  assert_success
}

@test "passes when other lines separate the pragma from the shopt" {
  write_script "${FIXTURE_CI}/spaced" \
    'set -Eeuo pipefail' \
    '# a comment between the two lines is fine' \
    'shopt -s inherit_errexit'
  run "${CHECK}"
  assert_success
}

@test "fails when the shopt is missing" {
  write_script "${FIXTURE_CI}/bare" 'set -Eeuo pipefail' 'echo hi'
  run "${CHECK}"
  assert_failure
  assert_output --partial "bare: missing 'shopt -s inherit_errexit'"
}

@test "fails when the shopt precedes the strict-mode pragma" {
  write_script "${FIXTURE_CI}/misordered" 'shopt -s inherit_errexit' 'set -Eeuo pipefail'
  run "${CHECK}"
  assert_failure
  assert_output --partial "precedes 'set -Eeuo pipefail'"
}

@test "fails when the shopt is present but strict mode is not" {
  write_script "${FIXTURE_CI}/no-strict" 'shopt -s inherit_errexit' 'echo hi'
  run "${CHECK}"
  assert_failure
  assert_output --partial "but no 'set -Eeuo pipefail'"
}

@test "fails when a shopt line is set to a different option" {
  write_script "${FIXTURE_CI}/wrong-opt" 'set -Eeuo pipefail' 'shopt -s nullglob'
  run "${CHECK}"
  assert_failure
  assert_output --partial "missing 'shopt -s inherit_errexit'"
}

@test "does not accept the shopt as a trailing comment or indented line" {
  write_script "${FIXTURE_CI}/indented" 'set -Eeuo pipefail' '  shopt -s inherit_errexit'
  run "${CHECK}"
  assert_failure
  assert_output --partial "missing 'shopt -s inherit_errexit'"
}

@test "flags a violation under .githooks" {
  write_script "${FIXTURE_HOOKS}/pre-push" 'set -Eeuo pipefail'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'pre-push: missing'
}

@test "flags a violation at the repo root" {
  write_script "${FIXTURE_ROOT}/run-tests" 'set -Eeuo pipefail'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'run-tests: missing'
}

@test "ignores a .ci file with no shell shebang" {
  printf '%s\n' 'yq' 'shellcheck' > "${FIXTURE_CI}/required-tools"
  run "${CHECK}"
  assert_success
}

@test "reports every offender rather than stopping at the first" {
  write_script "${FIXTURE_CI}/one" 'set -Eeuo pipefail'
  write_script "${FIXTURE_CI}/two" 'set -Eeuo pipefail'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'one: missing'
  assert_output --partial 'two: missing'
}

@test "an EXEMPT entry suppresses a real violation" {
  write_script "${FIXTURE_CI}/bootstrap" 'set -Eeuo pipefail'
  EXEMPT_OVERRIDE='bootstrap' run "${CHECK}"
  assert_success
}

@test "an EXEMPT entry naming no in-scope file is stale" {
  write_compliant "${FIXTURE_CI}/clean"
  EXEMPT_OVERRIDE='ghost' run "${CHECK}"
  assert_failure
  assert_output --partial 'stale EXEMPT entry: ghost'
}

@test "an EXEMPT entry naming a compliant file is stale" {
  write_compliant "${FIXTURE_CI}/clean"
  EXEMPT_OVERRIDE='clean' run "${CHECK}"
  assert_failure
  assert_output --partial 'stale EXEMPT entry: clean'
}

@test "a stale EXEMPT entry does not mask a separate real violation" {
  write_script "${FIXTURE_CI}/bare" 'set -Eeuo pipefail'
  write_compliant "${FIXTURE_CI}/clean"
  EXEMPT_OVERRIDE='clean' run "${CHECK}"
  assert_failure
  assert_output --partial 'stale EXEMPT entry: clean'
  assert_output --partial 'bare: missing'
}

@test "warns with a one-line summary when the audit fails" {
  write_script "${FIXTURE_CI}/bare" 'set -Eeuo pipefail'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'inherit_errexit audit failed'
}

@test "dies with an argument" {
  run --separate-stderr "${CHECK}" 'extra'
  assert_failure
  assert_stderr --partial 'Expected no arguments'
}

@test "--help prints the description and exits 0" {
  run "${CHECK}" '--help'
  assert_success
  assert_output --partial 'inherit_errexit'
}

@test "the shipped repo tree passes" {
  # Guards the real scope, not a fixture: the overrides above are cleared so the
  # check runs against .ci/, .githooks/, and the repo root as shipped.
  cd "${REPO_DIR}" || return 1
  unset EXEMPT_OVERRIDE CI_DIR_OVERRIDE HOOKS_DIR_OVERRIDE ROOT_DIR_OVERRIDE
  run "${CHECK}"
  assert_success
}
