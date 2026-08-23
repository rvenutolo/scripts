#!/usr/bin/env bats

# shellcheck disable=SC2016 # fixture bodies are literal shell text the lint reads, never expansions
bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  load '../test_helper/git_fixture'
  CHECK="${REPO_DIR}/.ci/check-errexit-predicate"
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

# Write a fixture defining a parser-backed helper, followed by the given call
# lines. The parser name is assembled at runtime so this file never contains a
# literal call the lint could read out of the suite itself.
write_parser_helper() {
  local -r path="$1"
  shift
  local -r parser="${PARSER_NAME:-y}q"
  write_script "${path}" \
    'function has_thing() {' \
    "  local n" \
    "  n=\"\$(${parser} eval '.a | length' \"\$1\")\"" \
    '  ((n > 0))' \
    '}' \
    "$@"
}

@test "passes on an empty scope" {
  run "${CHECK}"
  assert_success
}

@test "passes on a fixture with no parser-backed helper" {
  write_script "${FIXTURE_CI}/clean" \
    'function plain() { [[ -f "$1" ]]; }' \
    'if plain x; then echo hi; fi'
  run "${CHECK}"
  assert_success
}

@test "flags a parser-backed helper called from if" {
  write_parser_helper "${FIXTURE_CI}/offender" 'if has_thing x; then echo hi; fi'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'offender:'
  assert_output --partial '(via has_thing)'
}

@test "flags a negated if" {
  write_parser_helper "${FIXTURE_CI}/offender" 'if ! has_thing x; then echo hi; fi'
  run "${CHECK}"
  assert_failure
  assert_output --partial '(via has_thing)'
}

@test "flags an elif" {
  write_parser_helper "${FIXTURE_CI}/offender" 'if false; then :' 'elif has_thing x; then echo hi; fi'
  run "${CHECK}"
  assert_failure
  assert_output --partial '(via has_thing)'
}

@test "flags a while condition" {
  write_parser_helper "${FIXTURE_CI}/offender" 'while has_thing x; do break; done'
  run "${CHECK}"
  assert_failure
  assert_output --partial '(via has_thing)'
}

@test "flags an until condition" {
  write_parser_helper "${FIXTURE_CI}/offender" 'until has_thing x; do break; done'
  run "${CHECK}"
  assert_failure
  assert_output --partial '(via has_thing)'
}

@test "flags the accumulator idiom on the left of ||" {
  write_parser_helper "${FIXTURE_CI}/offender" 'rc=0' 'has_thing x || rc=1'
  run "${CHECK}"
  assert_failure
  assert_output --partial '(via has_thing)'
}

@test "flags a call on the left of &&" {
  write_parser_helper "${FIXTURE_CI}/offender" 'has_thing x && echo hi'
  run "${CHECK}"
  assert_failure
  assert_output --partial '(via has_thing)'
}

@test "does not flag a producer called through command substitution" {
  write_parser_helper "${FIXTURE_CI}/producer" 'n="$(has_thing x)"'
  run "${CHECK}"
  assert_success
}

@test "does not flag a producer called as a plain command" {
  write_parser_helper "${FIXTURE_CI}/producer" 'has_thing x > /dev/null'
  run "${CHECK}"
  assert_success
}

@test "jq counts as a parser, not only yq" {
  PARSER_NAME='j' write_parser_helper "${FIXTURE_CI}/offender" 'if has_thing x; then echo hi; fi'
  run "${CHECK}"
  assert_failure
  assert_output --partial '(via has_thing)'
}

@test "a parser named only in a body comment does not make a helper parser-backed" {
  write_script "${FIXTURE_CI}/commented" \
    'function has_thing() {' \
    '  # this helper deliberately avoids yq, see the design note' \
    '  [[ -f "$1" ]]' \
    '}' \
    'if has_thing x; then echo hi; fi'
  run "${CHECK}"
  assert_success
}

@test "a call site inside a comment is not a call site" {
  write_parser_helper "${FIXTURE_CI}/commented" \
    '# if has_thing x; then ... would be wrong, so we do not' \
    'n="$(has_thing x)"'
  run "${CHECK}"
  assert_success
}

@test "a parser in one helper does not implicate a different helper" {
  write_script "${FIXTURE_CI}/mixed" \
    'function parses() {' \
    "  yq eval '.a' \"\$1\"" \
    '}' \
    'function plain() { [[ -f "$1" ]]; }' \
    'if plain x; then echo hi; fi' \
    'n="$(parses x)"'
  run "${CHECK}"
  assert_success
}

@test "flags a violation under .githooks" {
  write_parser_helper "${FIXTURE_HOOKS}/pre-push" 'if has_thing x; then echo hi; fi'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'pre-push:'
}

@test "flags a violation at the repo root" {
  write_parser_helper "${FIXTURE_ROOT}/run-tests" 'if has_thing x; then echo hi; fi'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'run-tests:'
}

@test "reports every offending call site, not just the first" {
  write_parser_helper "${FIXTURE_CI}/offender" \
    'if has_thing x; then echo hi; fi' \
    'if has_thing y; then echo hi; fi'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'has_thing x'
  assert_output --partial 'has_thing y'
}

@test "an EXEMPT entry suppresses a real violation" {
  write_parser_helper "${FIXTURE_CI}/offender" 'if has_thing x; then echo hi; fi'
  EXEMPT_OVERRIDE='offender' run "${CHECK}"
  assert_success
}

@test "an EXEMPT entry naming no in-scope file is stale" {
  write_parser_helper "${FIXTURE_CI}/producer" 'n="$(has_thing x)"'
  EXEMPT_OVERRIDE='ghost' run "${CHECK}"
  assert_failure
  assert_output --partial 'stale EXEMPT entry: ghost'
}

@test "an EXEMPT entry naming a clean file is stale" {
  write_parser_helper "${FIXTURE_CI}/producer" 'n="$(has_thing x)"'
  EXEMPT_OVERRIDE='producer' run "${CHECK}"
  assert_failure
  assert_output --partial 'stale EXEMPT entry: producer'
}

@test "a stale EXEMPT entry does not mask a separate real violation" {
  write_parser_helper "${FIXTURE_CI}/offender" 'if has_thing x; then echo hi; fi'
  write_parser_helper "${FIXTURE_CI}/producer" 'n="$(has_thing x)"'
  EXEMPT_OVERRIDE='producer' run "${CHECK}"
  assert_failure
  assert_output --partial 'stale EXEMPT entry: producer'
  assert_output --partial '(via has_thing)'
}

@test "warns with a one-line summary when the audit fails" {
  write_parser_helper "${FIXTURE_CI}/offender" 'if has_thing x; then echo hi; fi'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'errexit-predicate audit failed'
}

@test "ignores a file with no shell shebang" {
  printf '%s\n' 'function has_thing() { yq eval . "$1"; }' 'if has_thing x; then :; fi' \
    > "${FIXTURE_CI}/notes.txt"
  run "${CHECK}"
  assert_success
}

@test "dies with an argument" {
  run --separate-stderr "${CHECK}" 'extra'
  assert_failure
  assert_stderr --partial 'Expected no arguments'
}

@test "--help prints the description and exits 0" {
  run "${CHECK}" '--help'
  assert_success
  assert_output --partial 'condition'
}

@test "the shipped repo tree passes" {
  # Guards the real scope, not a fixture: the overrides above are cleared so the
  # check runs against .ci/, .githooks/, and the repo root as shipped.
  cd "${REPO_DIR}" || return 1
  unset EXEMPT_OVERRIDE CI_DIR_OVERRIDE HOOKS_DIR_OVERRIDE ROOT_DIR_OVERRIDE
  run "${CHECK}"
  assert_success
}
