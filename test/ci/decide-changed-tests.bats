setup() {
  load '../test_helper/common'
  SCRIPT="${REPO_DIR}/.ci/decide-changed-tests"
  CHANGED="${BATS_TEST_TMPDIR}/changed.txt"
}

# Write the given paths, one per line, into the changed-paths fixture file.
write_changed() {
  printf '%s\n' "$@" > "${CHANGED}"
}

@test "a .ci/ path runs the suite" {
  write_changed '.ci/check-executable-bit'
  run "${SCRIPT}" "${CHANGED}"
  assert_success
  assert_output --partial 'run=true'
}

@test "each repo-root runner runs the suite" {
  local runner
  for runner in check-scripts shellcheck-scripts run-tests run-install-scripts run-set-up-scripts; do
    write_changed "${runner}"
    run "${SCRIPT}" "${CHANGED}"
    assert_success
    assert_output --partial 'run=true'
  done
}

@test "a scripts/functions path runs the suite" {
  write_changed 'scripts/functions/arrays.bash'
  run "${SCRIPT}" "${CHANGED}"
  assert_output --partial 'run=true'
}

@test ".editorconfig runs the suite" {
  # Deliberately not in IRRELEVANT: shfmt reads its style from this file.
  write_changed '.editorconfig'
  run "${SCRIPT}" "${CHANGED}"
  assert_output --partial 'run=true'
}

@test "an unanticipated path runs the suite" {
  # The polarity guarantee: a directory nobody enumerated must not be skipped.
  write_changed 'some/brand/new/dir/thing.txt'
  run "${SCRIPT}" "${CHANGED}"
  assert_output --partial 'run=true'
}

@test "a workflow file runs the suite" {
  write_changed '.github/workflows/links.yml'
  run "${SCRIPT}" "${CHANGED}"
  assert_output --partial 'run=true'
}

@test "an all-irrelevant change set skips the suite" {
  write_changed 'README.md' 'CLAUDE.md' 'LICENSE' '.docs/invariant-index.md' \
    '.github/ISSUE_TEMPLATE/bug.yml'
  run "${SCRIPT}" "${CHANGED}"
  assert_success
  assert_output --partial 'run=false'
}

@test "a nested markdown file is irrelevant" {
  write_changed 'docs/superpowers/specs/x.md'
  run "${SCRIPT}" "${CHANGED}"
  assert_output --partial 'run=false'
}

@test "one relevant path among irrelevant ones runs the suite" {
  write_changed 'README.md' '.ci/check-executable-bit' 'LICENSE'
  run "${SCRIPT}" "${CHANGED}"
  assert_output --partial 'run=true'
}

@test "blank lines are ignored" {
  printf '%s\n' 'README.md' '' 'LICENSE' > "${CHANGED}"
  run "${SCRIPT}" "${CHANGED}"
  assert_output --partial 'run=false'
}

@test "an empty change set skips the suite" {
  : > "${CHANGED}"
  run "${SCRIPT}" "${CHANGED}"
  assert_success
  assert_output --partial 'run=false'
}

@test "the reason is reported for a skip" {
  : > "${CHANGED}"
  run "${SCRIPT}" "${CHANGED}"
  assert_output --partial 'no test-relevant paths changed'
}

@test "the reason names the triggering path" {
  write_changed '.ci/check-executable-bit'
  run "${SCRIPT}" "${CHANGED}"
  assert_output --partial 'changed .ci/check-executable-bit'
}

@test "a missing changed-paths file fails" {
  run "${SCRIPT}" "${BATS_TEST_TMPDIR}/absent.txt"
  assert_failure
  assert_output --partial 'does not exist'
}

@test "dies with no arguments" {
  run "${SCRIPT}"
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "dies with two arguments" {
  : > "${CHANGED}"
  run "${SCRIPT}" "${CHANGED}" extra
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "--help exits 0" {
  run "${SCRIPT}" --help
  assert_success
}
