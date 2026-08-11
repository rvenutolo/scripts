#!/usr/bin/env bats

# shellcheck disable=SC2016 # ${SCRIPTS_DIR} is literal fixture content the lint must match, never an expansion

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  load '../test_helper/git_fixture'
  CHECK="${REPO_DIR}/.ci/check-tree-scan-root"
  FIXTURE_CI="${BATS_TEST_TMPDIR}/ci"
  FIXTURE_HOOKS="${BATS_TEST_TMPDIR}/hooks"
  FIXTURE_ROOT="${BATS_TEST_TMPDIR}/root"
  mkdir -p "${FIXTURE_CI}" "${FIXTURE_HOOKS}" "${FIXTURE_ROOT}"
  # The check resolves REPO_DIR via `git rev-parse --show-toplevel`, so it must run
  # with cwd inside a git repo or it exits 128 before any scan. common.bash leaves
  # cwd at BATS_TEST_TMPDIR, which is deliberately not a repo (#248 hardening), so
  # give the check a throwaway fixture repo to resolve. Only REPO_DIR resolution
  # depends on it — the three scan roots come from the overrides below.
  FIXTURE_REPO="${BATS_TEST_TMPDIR}/repo"
  git_fixture::init "${FIXTURE_REPO}"
  cd "${FIXTURE_REPO}" || return 1
  # An empty EXEMPT by default: the shipped entries name real repo runners that do
  # not exist in a fixture dir and would otherwise read as stale.
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

@test "passes on a clean .ci fixture" {
  write_script "${FIXTURE_CI}/clean" 'echo hi'
  run "${CHECK}"
  assert_success
}

@test "passes on an empty scope" {
  run "${CHECK}"
  assert_success
}

@test "fails on a braced SCRIPTS_DIR scan root" {
  write_script "${FIXTURE_CI}/braced" 'readonly d="${SCRIPTS_DIR}/non-interactive"'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'braced'
}

@test "fails on an unbraced SCRIPTS_DIR scan root" {
  write_script "${FIXTURE_CI}/unbraced" 'readonly d="$SCRIPTS_DIR/non-interactive"'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'unbraced'
}

@test "allows the canonical library-sourcing line" {
  write_script "${FIXTURE_CI}/sourcer" 'source "${SCRIPTS_DIR}/.functions.bash"' 'echo hi'
  run "${CHECK}"
  assert_success
}

@test "allows a comment naming the variable" {
  write_script "${FIXTURE_CI}/commented" '# .functions.bash is sourced from ${SCRIPTS_DIR}' 'echo hi'
  run "${CHECK}"
  assert_success
}

@test "does not flag a different variable that ends in SCRIPTS_DIR" {
  write_script "${FIXTURE_CI}/docsvar" \
    'readonly DOCS_SCRIPTS_DIR="${DOCS_DIR}/scripts"' \
    'echo "${DOCS_SCRIPTS_DIR}"'
  run "${CHECK}"
  assert_success
}

@test "flags an offending line under .githooks" {
  write_script "${FIXTURE_HOOKS}/pre-push" 'readonly d="${SCRIPTS_DIR}/install"'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'pre-push'
}

@test "flags an offending repo-root runner" {
  write_script "${FIXTURE_ROOT}/some-runner" 'readonly d="${SCRIPTS_DIR}/set_up"'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'some-runner'
}

@test "reports the offending line number and text" {
  write_script "${FIXTURE_CI}/numbered" 'echo one' 'readonly d="${SCRIPTS_DIR}/misc"'
  run "${CHECK}"
  assert_failure
  assert_output --partial '3: '
  assert_output --partial 'SCRIPTS_DIR'
}

@test "an EXEMPT entry suppresses an offending file" {
  write_script "${FIXTURE_CI}/allowed" 'readonly d="${SCRIPTS_DIR}/install"'
  EXEMPT_OVERRIDE='allowed' run "${CHECK}"
  assert_success
}

@test "fails when an EXEMPT entry names a file that does not exist" {
  write_script "${FIXTURE_CI}/clean" 'echo hi'
  EXEMPT_OVERRIDE='ghost' run "${CHECK}"
  assert_failure
  assert_output --partial 'stale EXEMPT entry: ghost'
}

@test "fails when an EXEMPT entry names a file with no offending reference" {
  write_script "${FIXTURE_CI}/clean" 'echo hi'
  EXEMPT_OVERRIDE='clean' run "${CHECK}"
  assert_failure
  assert_output --partial 'stale EXEMPT entry: clean'
}

@test "reports every offending file when several are broken" {
  write_script "${FIXTURE_CI}/first" 'readonly d="${SCRIPTS_DIR}/install"'
  write_script "${FIXTURE_CI}/second" 'readonly d="${SCRIPTS_DIR}/misc"'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'first'
  assert_output --partial 'second'
}

@test "passes on the real repo tree" {
  # The shipped EXEMPT and real scope, not the fixture: this is the assertion that
  # the invariant actually holds in this repo, and it must be driven with the real
  # defaults rather than the overrides above.
  unset EXEMPT_OVERRIDE CI_DIR_OVERRIDE HOOKS_DIR_OVERRIDE ROOT_DIR_OVERRIDE
  cd "${REPO_DIR}" || return 1
  run "${CHECK}"
  assert_success
}

@test "dies when given an argument" {
  run "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "prints help and exits 0 for --help" {
  run "${CHECK}" --help
  assert_success
  assert_output --partial 'SCRIPTS_DIR'
}
