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

# A single-bracket stderr test. Rule 1 covers both bracket spellings.
raw_stderr_bracket() {
  printf '  [ -z "${%s}" ]' 'stderr'
}

# A line holding a raw stdout glob, same device.
raw_output_glob() {
  printf '  [[ "${%s}" == *%s* ]]' 'output' "'boom'"
}

# A single-bracket stdout test.
raw_output_bracket() {
  printf '  [ -z "${%s}" ]' 'output'
}

# A numeric stdout comparison — rule 3's carve-out, since bats-assert has no
# numeric helper.
numeric_output_test() {
  printf '  [ "${%s}" -ge 3 ]' 'output'
}

# A stdout length test. Rule 3 matches the expansion, not the length of it.
length_output_test() {
  printf '  [[ "${#%s}" -eq 32 ]]' 'output'
}

# A stdout expansion outside any bracket test, which no rule may flag.
plain_output_use() {
  printf '  local captured="${%s}"' 'output'
}

# A line holding a raw status test, same device.
raw_status_test() {
  printf '  [[ "${%s}" -eq 1 ]]' 'status'
}

# A single-bracket status test.
raw_status_bracket() {
  printf '  [ "${%s}" -ne 0 ]' 'status'
}

# A status expansion outside any bracket test, which no rule may flag.
plain_status_use() {
  printf '  echo "${%s}"' 'status'
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

@test "rule 1: fires on a single-bracket stderr test too" {
  write_test_file "${FIXTURE_TEST}/functions/single.bats" \
    '@test "x" {' \
    '  run --separate-stderr some::fn' \
    "$(raw_stderr_bracket)" \
    '}'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'rule1'
}

@test "rule 3: fails on a raw stdout glob" {
  write_test_file "${FIXTURE_TEST}/functions/out.bats" \
    '@test "x" {' \
    '  run some::fn x' \
    "$(raw_output_glob)" \
    '}'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'out.bats'
  assert_output --partial 'rule3'
}

@test "rule 3: fails on a single-bracket stdout test" {
  write_test_file "${FIXTURE_TEST}/functions/outb.bats" \
    '@test "x" {' \
    '  run some::fn' \
    "$(raw_output_bracket)" \
    '}'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'rule3'
}

@test "rule 3: applies in test/ci and test/root too" {
  write_test_file "${FIXTURE_TEST}/ci/out.bats" \
    '@test "x" {' \
    "$(raw_output_glob)" \
    '}'
  write_test_file "${FIXTURE_TEST}/root/out.bats" \
    '@test "x" {' \
    "$(raw_output_glob)" \
    '}'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'ci/out.bats'
  assert_output --partial 'root/out.bats'
}

@test "rule 3: allows a numeric stdout comparison" {
  write_test_file "${FIXTURE_TEST}/functions/count.bats" \
    '@test "x" {' \
    '  run some::fn' \
    "$(numeric_output_test)" \
    '}'
  run "${CHECK}"
  assert_success
}

@test "rule 3: allows a stdout length test" {
  write_test_file "${FIXTURE_TEST}/functions/len.bats" \
    '@test "x" {' \
    '  run some::fn' \
    "$(length_output_test)" \
    '}'
  run "${CHECK}"
  assert_success
}

@test "rule 3: does not fire outside a bracket test" {
  write_test_file "${FIXTURE_TEST}/functions/capture.bats" \
    '@test "x" {' \
    '  run some::fn' \
    "$(plain_output_use)" \
    '}'
  run "${CHECK}"
  assert_success
}

@test "rule 4: fails on a raw status test" {
  write_test_file "${FIXTURE_TEST}/functions/st.bats" \
    '@test "x" {' \
    '  run some::fn x' \
    "$(raw_status_test)" \
    '}'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'st.bats'
  assert_output --partial 'rule4'
}

@test "rule 4: fails on a single-bracket status test" {
  write_test_file "${FIXTURE_TEST}/functions/stb.bats" \
    '@test "x" {' \
    '  run some::fn' \
    "$(raw_status_bracket)" \
    '}'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'rule4'
}

@test "rule 4 has no numeric carve-out where rule 3 does" {
  write_test_file "${FIXTURE_TEST}/functions/stnum.bats" \
    '@test "x" {' \
    '  run some::fn' \
    "$(numeric_output_test)" \
    "$(raw_status_test)" \
    '}'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'rule4'
  refute_output --partial 'rule3'
}

@test "rule 4: does not fire outside a bracket test" {
  write_test_file "${FIXTURE_TEST}/functions/echo.bats" \
    '@test "x" {' \
    '  run some::fn' \
    "$(plain_status_use)" \
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

# The scope walk skips a subdirectory that does not exist rather than dying, so a
# repo mid-reorganisation — test/root/ not yet created, say — still gets the other
# two scanned instead of the whole lint failing or, worse, reading clean.
@test "a missing scope subdirectory is skipped and the rest still scanned" {
  rmdir "${FIXTURE_TEST}/root"
  write_test_file "${FIXTURE_TEST}/functions/bad.bats" \
    '@test "x" {' \
    '  run --separate-stderr some::fn x' \
    '  assert_failure' \
    "$(raw_stderr_glob)" \
    '}'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'bad.bats'
}
