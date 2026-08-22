#!/usr/bin/env bats

# shellcheck disable=SC2016 # the printf format holds a literal ${...} the lint must see, never an expansion

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  load '../test_helper/git_fixture'
  CHECK="${REPO_DIR}/.ci/check-stderr-assertions"
  FIXTURE_TEST="${BATS_TEST_TMPDIR}/test"
  mkdir -p "${FIXTURE_TEST}/functions" "${FIXTURE_TEST}/ci" "${FIXTURE_TEST}/root"
  # The check resolves REPO_DIR via `git rev-parse --show-toplevel`, so it must run with
  # cwd inside a git repo or it exits 128 before any scan. common.bash leaves cwd at
  # BATS_TEST_TMPDIR, which is deliberately not a repo (#248 hardening), so give the
  # check a throwaway fixture repo. Only REPO_DIR resolution depends on it — the scan
  # root comes from the override below.
  FIXTURE_REPO="${BATS_TEST_TMPDIR}/repo"
  git_fixture::init "${FIXTURE_REPO}"
  cd "${FIXTURE_REPO}" || return 1
  export EXEMPT_OVERRIDE=''
  export TEST_DIR_OVERRIDE="${FIXTURE_TEST}"
}

# Write a fixture .bats file from the given body lines.
#
# Bodies are composed at call sites with printf and a '%s' for the offending variable
# name, so no literal stderr expansion ever appears in this file's source. Without that
# device the lint would flag its own paired test, which is the trap documented for
# .ci/check-tree-scan-root.
write_test_file() {
  local -r path="$1"
  shift
  printf '%s\n' "$@" > "${path}"
}

# A line holding a raw stderr glob, built so this source contains no literal expansion.
raw_stderr_glob() {
  printf '  [[ "${%s}" == *%s* ]]' 'stderr' "'boom'"
}

@test "passes on an empty scope" {
  run "${CHECK}"
  assert_success
}

@test "passes on a file using assert_stderr" {
  write_test_file "${FIXTURE_TEST}/functions/good.bats" \
    '@test "x" {' \
    '  run --separate-stderr some::fn x' \
    '  assert_failure' \
    "  assert_stderr --partial 'boom'" \
    '}'
  run "${CHECK}"
  assert_success
}

@test "rule 1: fails on a raw stderr glob" {
  write_test_file "${FIXTURE_TEST}/functions/bad.bats" \
    '@test "x" {' \
    '  run --separate-stderr some::fn x' \
    "$(raw_stderr_glob)" \
    '}'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'bad.bats'
  assert_output --partial 'rule1'
}

@test "rule 1: applies in test/ci and test/root too" {
  write_test_file "${FIXTURE_TEST}/ci/bad.bats" \
    '@test "x" {' \
    "$(raw_stderr_glob)" \
    '}'
  write_test_file "${FIXTURE_TEST}/root/bad.bats" \
    '@test "x" {' \
    "$(raw_stderr_glob)" \
    '}'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'ci/bad.bats'
  assert_output --partial 'root/bad.bats'
}

@test "rule 2: fails on a substring stdout assertion after --separate-stderr" {
  write_test_file "${FIXTURE_TEST}/functions/trap.bats" \
    '@test "x" {' \
    '  run --separate-stderr some::fn x' \
    '  assert_failure' \
    "  assert_output --partial 'Expected no arguments'" \
    '}'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'rule2'
}

@test "rule 2: allows an explicit empty-stdout assertion" {
  write_test_file "${FIXTURE_TEST}/functions/empty.bats" \
    '@test "x" {' \
    '  run --separate-stderr some::fn' \
    '  assert_success' \
    "  assert_output ''" \
    '}'
  run "${CHECK}"
  assert_success
}

@test "rule 2: allows a bare refute_output" {
  write_test_file "${FIXTURE_TEST}/functions/bare.bats" \
    '@test "x" {' \
    '  run --separate-stderr some::fn' \
    '  assert_success' \
    '  refute_output' \
    '}'
  run "${CHECK}"
  assert_success
}

@test "rule 2: does not fire after a plain run" {
  write_test_file "${FIXTURE_TEST}/functions/merged.bats" \
    '@test "x" {' \
    '  run some::fn x' \
    '  assert_failure' \
    "  assert_output --partial 'Expected no arguments'" \
    '}'
  run "${CHECK}"
  assert_success
}

@test "rule 2: block state resets at the next @test" {
  write_test_file "${FIXTURE_TEST}/functions/reset.bats" \
    '@test "split" {' \
    '  run --separate-stderr some::fn' \
    '  refute_output' \
    '}' \
    '' \
    '@test "merged" {' \
    '  run some::fn x' \
    "  assert_output --partial 'Expected no arguments'" \
    '}'
  run "${CHECK}"
  assert_success
}

@test "ignores non-.bats files in scope" {
  write_test_file "${FIXTURE_TEST}/functions/notes.md" \
    "$(raw_stderr_glob)"
  run "${CHECK}"
  assert_success
}

@test "an EXEMPT entry suppresses a flagged file" {
  write_test_file "${FIXTURE_TEST}/functions/bad.bats" \
    '@test "x" {' \
    '  run --separate-stderr some::fn x' \
    "$(raw_stderr_glob)" \
    '}'
  EXEMPT_OVERRIDE='bad.bats' run "${CHECK}"
  assert_success
}

@test "a stale EXEMPT entry naming no file fails" {
  EXEMPT_OVERRIDE='ghost.bats' run "${CHECK}"
  assert_failure
  assert_output --partial 'stale EXEMPT entry: ghost.bats'
}

@test "a stale EXEMPT entry naming a clean file fails" {
  write_test_file "${FIXTURE_TEST}/functions/clean.bats" \
    '@test "x" {' \
    '  run true' \
    '  assert_success' \
    '}'
  EXEMPT_OVERRIDE='clean.bats' run "${CHECK}"
  assert_failure
  assert_output --partial 'stale EXEMPT entry: clean.bats'
}

@test "dies with an unexpected argument" {
  run "${CHECK}" extra
  assert_failure
  assert_output --partial 'Expected no arguments'
}
