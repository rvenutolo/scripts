bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  load '../test_helper/git_fixture'
  CHECK="${REPO_DIR}/.ci/check-comment-archaeology"
  export EXEMPT_OVERRIDE=''
  FIXTURE="${BATS_TEST_TMPDIR}/repo"
  git_fixture::init "${FIXTURE}"
  export SCAN_ROOT_OVERRIDE="${FIXTURE}"
  # This file is itself in scope for the lint under test, so an offending fixture
  # line cannot be spelled literally here — it would make this file fail the very
  # lint it verifies. Compose the token at runtime instead, the same device
  # check-stderr-assertions.bats uses for its fixture lines. Lines that are meant
  # NOT to match (a step index, a two-digit number, a hex colour) are spelled
  # literally on purpose: they double as live proof the pattern ignores them.
  HASH='#'
  # A tracked, hit-free baseline. An empty scan is a failure rather than a clean
  # pass, and several tests below add no tracked file of their own.
  printf '%s\n' '# baseline' > "${FIXTURE}/baseline.bash"
  git_fixture::run "${FIXTURE}" add baseline.bash
  # The check runs `git rev-parse --show-toplevel` unconditionally (the seam overrides a
  # derived path, not REPO_DIR itself), and common.bash leaves cwd at BATS_TEST_TMPDIR,
  # which is deliberately not a repo. Without this cd the check exits 128 before scanning.
  cd "${FIXTURE}" || return 1
}

@test "passes over a tree with no numbered references" {
  printf '%s\n' '# a plain comment' > "${FIXTURE}/clean.bash"
  git_fixture::run "${FIXTURE}" add clean.bash
  run --separate-stderr "${CHECK}"
  assert_success
}

@test "flags a trailing parenthetical in a comment" {
  printf '%s\n' "# the guard is required (${HASH}290)." > "${FIXTURE}/dirty.bash"
  git_fixture::run "${FIXTURE}" add dirty.bash
  run --separate-stderr "${CHECK}"
  assert_failure 1
  assert_stderr --partial 'dirty.bash'
}

@test "flags a number inside a runtime string" {
  printf '%s\n' "log::die \"repo mutated (${HASH}248)\"" > "${FIXTURE}/die.bash"
  git_fixture::run "${FIXTURE}" add die.bash
  run --separate-stderr "${CHECK}"
  assert_failure 1
  assert_stderr --partial 'die.bash'
}

@test "does not flag a step index" {
  printf '%s\n' "# @stdout One line, e.g. \`job 'bats' step #2 (Run BATS)\`." > "${FIXTURE}/idx.bash"
  git_fixture::run "${FIXTURE}" add idx.bash
  run --separate-stderr "${CHECK}"
  assert_success
}

@test "does not flag a two-digit reference" {
  printf '%s\n' '# see step #42 of the runbook' > "${FIXTURE}/two.bash"
  git_fixture::run "${FIXTURE}" add two.bash
  run --separate-stderr "${CHECK}"
  assert_success
}

@test "does not flag a six-digit hex colour" {
  printf '%s\n' '# accent: #123456' > "${FIXTURE}/hex.bash"
  git_fixture::run "${FIXTURE}" add hex.bash
  run --separate-stderr "${CHECK}"
  assert_success
}

@test "does not flag \${#output} or \$#" {
  # shellcheck disable=SC2016 # the unexpanded literals are the fixture's whole point
  printf '%s\n' 'n="${#output}"; m="$#"' > "${FIXTURE}/expand.bash"
  git_fixture::run "${FIXTURE}" add expand.bash
  run --separate-stderr "${CHECK}"
  assert_success
}

@test "does not flag an untracked file" {
  printf '%s\n' "# stale (${HASH}290)." > "${FIXTURE}/untracked.bash"
  run --separate-stderr "${CHECK}"
  assert_success
}

@test "does not flag scripts/other" {
  mkdir --parents "${FIXTURE}/scripts/other"
  printf '%s\n' "# third-party (${HASH}290)." > "${FIXTURE}/scripts/other/vendor.bash"
  git_fixture::run "${FIXTURE}" add scripts/other/vendor.bash
  run --separate-stderr "${CHECK}"
  assert_success
}

@test "an EXEMPT entry suppresses its hit" {
  printf '%s\n' "@test \"pins the fixture escape (${HASH}248)\" {" > "${FIXTURE}/regress.bats"
  git_fixture::run "${FIXTURE}" add regress.bats
  EXEMPT_OVERRIDE='regress.bats::248' run --separate-stderr "${CHECK}"
  assert_success
}

@test "an EXEMPT entry naming no file is stale" {
  EXEMPT_OVERRIDE='does/not/exist.bats::248' run --separate-stderr "${CHECK}"
  assert_failure 1
  assert_stderr --partial 'stale EXEMPT entry'
}

@test "an EXEMPT entry whose file has no such hit is stale" {
  printf '%s\n' '# a plain comment' > "${FIXTURE}/clean.bash"
  git_fixture::run "${FIXTURE}" add clean.bash
  EXEMPT_OVERRIDE='clean.bash::248' run --separate-stderr "${CHECK}"
  assert_failure 1
  assert_stderr --partial 'stale EXEMPT entry'
}

@test "flags both numbers on a line that carries two" {
  printf '%s\n' "# the guard is required (${HASH}290) and the trap fires (${HASH}248)." \
    > "${FIXTURE}/multi.bash"
  git_fixture::run "${FIXTURE}" add multi.bash
  run --separate-stderr "${CHECK}"
  assert_failure 1
  assert_stderr --partial '290'
  assert_stderr --partial '248'
  # One record per number, not one per line. The second report line is the whole
  # point of the walk-forward in scan_for_hits; index 2 is the closing warning.
  assert_stderr_line --index 0 --partial 'multi.bash:1:'
  assert_stderr_line --index 1 --partial 'multi.bash:1:'
}

@test "exempting one of two numbers on a line leaves the other flagged" {
  printf '%s\n' "# the guard is required (${HASH}290) and the trap fires (${HASH}248)." \
    > "${FIXTURE}/multi.bash"
  git_fixture::run "${FIXTURE}" add multi.bash
  EXEMPT_OVERRIDE='multi.bash::290' run --separate-stderr "${CHECK}"
  assert_failure 1
  assert_stderr --partial '248'
  # Absence is asserted structurally rather than by substring: a report line
  # echoes the whole source line, which still carries the exempted number, so
  # what proves the suppression is that exactly one record survives. Index 1 is
  # the closing warning, not a second hit.
  assert_stderr_line --index 0 --partial 'multi.bash:1:'
  refute_stderr_line --index 1 --partial 'multi.bash'
}

@test "dies when the scan root does not exist" {
  SCAN_ROOT_OVERRIDE="${BATS_TEST_TMPDIR}/absent" run --separate-stderr "${CHECK}"
  assert_failure 1
  assert_stderr --partial 'does not exist'
}

@test "dies when the scan finds no files at all" {
  local empty="${BATS_TEST_TMPDIR}/empty"
  git_fixture::init "${empty}"
  SCAN_ROOT_OVERRIDE="${empty}" run --separate-stderr "${CHECK}"
  assert_failure 1
  assert_stderr --partial 'no in-scope files'
}

@test "rejects arguments" {
  run --separate-stderr "${CHECK}" 'extra'
  assert_failure 1
  assert_stderr --partial 'Expected no arguments'
}
