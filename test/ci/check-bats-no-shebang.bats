bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  load '../test_helper/git_fixture'
  CHECK="${REPO_DIR}/.ci/check-bats-no-shebang"
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
  export TEST_DIR_OVERRIDE="${FIXTURE_TEST}"
}

# Write a fixture .bats file from the given body lines. Shebang literals are safe
# to spell in this source: the lint judges only the FIRST line of each in-scope
# file, and this file's first line is bats_require_minimum_version.
write_test_file() {
  local -r path="$1"
  shift
  printf '%s\n' "$@" > "${path}"
}

@test "passes on a tree with no shebangs" {
  write_test_file "${FIXTURE_TEST}/functions/good.bats" \
    'setup() {' \
    "  load '../test_helper/common'" \
    '}' \
    '@test "x" { run true; }'
  run "${CHECK}"
  assert_success
  refute_output
}

@test "passes when a scan subdir is absent" {
  rm -r "${FIXTURE_TEST}/ci" "${FIXTURE_TEST}/root"
  write_test_file "${FIXTURE_TEST}/functions/good.bats" \
    '@test "x" { run true; }'
  run "${CHECK}"
  assert_success
}

@test "passes on an empty .bats file" {
  : > "${FIXTURE_TEST}/functions/empty.bats"
  run "${CHECK}"
  assert_success
}

@test "fails on a first-line bats shebang" {
  write_test_file "${FIXTURE_TEST}/functions/bad.bats" \
    '#!/usr/bin/env bats' \
    '' \
    '@test "x" { run true; }'
  run "${CHECK}"
  assert_failure 1
  assert_output --partial 'functions/bad.bats'
}

@test "fails on a first-line bash shebang" {
  write_test_file "${FIXTURE_TEST}/ci/bad.bats" \
    '#!/usr/bin/env bash' \
    '@test "x" { run true; }'
  run "${CHECK}"
  assert_failure 1
  assert_output --partial 'ci/bad.bats'
}

@test "reports every offender across all three subdirs" {
  write_test_file "${FIXTURE_TEST}/functions/a.bats" \
    '#!/usr/bin/env bats' \
    '@test "x" { run true; }'
  write_test_file "${FIXTURE_TEST}/ci/b.bats" \
    '#!/usr/bin/env bats' \
    '@test "x" { run true; }'
  write_test_file "${FIXTURE_TEST}/root/c.bats" \
    '#!/usr/bin/env bats' \
    '@test "x" { run true; }'
  run "${CHECK}"
  assert_failure 1
  assert_output --partial 'functions/a.bats'
  assert_output --partial 'ci/b.bats'
  assert_output --partial 'root/c.bats'
}

@test "ignores a shebang literal past the first line" {
  write_test_file "${FIXTURE_TEST}/functions/fixture.bats" \
    '@test "x" {' \
    "  printf '%s\\n' '#!/usr/bin/env bats' > \"\${BATS_TEST_TMPDIR}/f\"" \
    '  run true' \
    '  assert_success' \
    '}'
  run "${CHECK}"
  assert_success
}

@test "ignores non-bats files in the scan dirs" {
  write_test_file "${FIXTURE_TEST}/functions/helper.bash" \
    '#!/usr/bin/env bash' \
    'true'
  run "${CHECK}"
  assert_success
}

@test "--help exits 0 and prints the description" {
  run "${CHECK}" --help
  assert_success
  assert_output --partial 'shebang'
}

@test "dies with an unexpected argument" {
  run "${CHECK}" extra
  assert_failure
  assert_output --partial 'Expected no arguments'
}
