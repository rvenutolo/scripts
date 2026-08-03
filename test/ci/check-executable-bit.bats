setup() {
  load '../test_helper/common'
  # Capture the real check path BEFORE any cd into the fixture repo — REPO_DIR
  # from common.bash points at the real repo here, and the tests cd away.
  CHECK="${REPO_DIR}/.ci/check-executable-bit"
  REAL_REPO_DIR="${REPO_DIR}"
  REPO="${BATS_TEST_TMPDIR}/repo"

  # The check resolves its own repo root via `git rev-parse --show-toplevel`
  # from the CWD and scans it with shell_scripts::find, so a bare `git init`
  # tmpdir is all the isolation needed. SCRIPTS_DIR keeps pointing at the real
  # library: the check sources it, but classifies purely on paths relative to
  # the repo root, so nothing has to be staged into the fixture.
  mkdir --parents "${REPO}"/scripts/{non-interactive,interactive,misc,functions,install,set_up}
  mkdir --parents "${REPO}/.ci" "${REPO}/.githooks" "${REPO}/test/ci" "${REPO}/lib"
  git init --quiet "${REPO}"

  # One compliant file in every enforced location, so the default tree passes
  # and each failure test introduces exactly one violation of its own.
  make_script 'scripts/non-interactive/good' exec
  make_script 'scripts/interactive/good' exec
  make_script 'scripts/misc/good' exec
  make_script '.ci/check-good' exec
  make_script '.githooks/good-hook' exec
  make_script 'run-tests' exec
  make_script 'scripts/functions/topic.bash'
  make_bats 'test/ci/thing.bats'
}

# Apply the requested mode to a fixture file: `exec` makes it executable,
# anything else (including empty) makes it non-executable.
set_fixture_mode() {
  local -r path="$1"
  local -r mode="$2"
  if [[ "${mode}" == 'exec' ]]; then
    chmod +x "${REPO}/${path}"
  else
    chmod -x "${REPO}/${path}"
  fi
}

# Write a shebang-bearing file at ${REPO}/<path>. Pass `exec` as $2 to make it
# executable; omit $2 for a non-executable one.
make_script() {
  printf '#!/usr/bin/env bash\ntrue\n' > "${REPO}/$1"
  set_fixture_mode "$1" "${2:-}"
}

# Write a .bats file (no shebang — bats files start with a function) at
# ${REPO}/<path>. Pass `exec` as $2 to make it executable.
make_bats() {
  printf '@test "x" { true; }\n' > "${REPO}/$1"
  set_fixture_mode "$1" "${2:-}"
}

# Run the check against the fixture repo. Must cd first so the check's
# `git rev-parse --show-toplevel` resolves to the fixture.
run_check() {
  cd "${REPO}"
  run "${CHECK}" "$@"
}

@test "passes on a clean fixture tree" {
  run_check
  assert_success
}

@test "fails when a script under scripts/non-interactive/ is not executable" {
  make_script 'scripts/non-interactive/bad'
  run_check
  assert_failure
  assert_output --partial 'scripts/non-interactive/bad'
  assert_output --partial 'must be executable'
}

@test "fails when a script under scripts/interactive/ is not executable" {
  make_script 'scripts/interactive/bad'
  run_check
  assert_failure
  assert_output --partial 'scripts/interactive/bad'
  assert_output --partial 'must be executable'
}

@test "fails when a script under scripts/misc/ is not executable" {
  make_script 'scripts/misc/bad'
  run_check
  assert_failure
  assert_output --partial 'scripts/misc/bad'
  assert_output --partial 'must be executable'
}

@test "fails when a script under .ci/ is not executable" {
  make_script '.ci/check-bad'
  run_check
  assert_failure
  assert_output --partial '.ci/check-bad'
  assert_output --partial 'must be executable'
}

@test "fails when a hook under .githooks/ is not executable" {
  make_script '.githooks/bad-hook'
  run_check
  assert_failure
  assert_output --partial '.githooks/bad-hook'
  assert_output --partial 'must be executable'
}

@test "fails when a repo-root runner is not executable" {
  make_script 'run-set-up-scripts'
  run_check
  assert_failure
  assert_output --partial 'run-set-up-scripts'
  assert_output --partial 'must be executable'
}

@test "fails when a functions library file is executable" {
  make_script 'scripts/functions/oops.bash' exec
  run_check
  assert_failure
  assert_output --partial 'scripts/functions/oops.bash'
  assert_output --partial 'must not be executable'
}

@test "passes when a functions library file is not executable" {
  make_script 'scripts/functions/fine.bash'
  run_check
  assert_success
}

@test "fails when a bats file is executable" {
  make_bats 'test/ci/oops.bats' exec
  run_check
  assert_failure
  assert_output --partial 'test/ci/oops.bats'
  assert_output --partial 'must not be executable'
}

@test "passes when a non-executable script sits under scripts/install/" {
  make_script 'scripts/install/00_MARKER'
  run_check
  assert_success
}

@test "passes when a non-executable script sits under scripts/set_up/" {
  make_script 'scripts/set_up/disabled-thing'
  run_check
  assert_success
}

@test "passes on a shell-extension file with no shebang" {
  # shfmt --find matches by extension as well as by shebang, so this file DOES
  # reach rule 3 — only assert_executable's shebang gate lets it through.
  # Deleting that gate makes this test fail, which is the point.
  printf 'echo hi\n' > "${REPO}/scripts/non-interactive/notes.sh"
  chmod -x "${REPO}/scripts/non-interactive/notes.sh"
  run_check
  assert_success
}

@test "ignores a shebang script in an unenforced subdirectory" {
  make_script 'lib/helper'
  run_check
  assert_success
}

@test "reports every violation in a single run" {
  make_script 'scripts/non-interactive/bad-one'
  make_script 'scripts/functions/bad-two.bash' exec
  run_check
  assert_failure
  assert_output --partial 'scripts/non-interactive/bad-one'
  assert_output --partial 'scripts/functions/bad-two.bash'
}

@test "prints help and exits 0 for --help" {
  run_check --help
  assert_success
}

@test "dies when given an unexpected argument" {
  run_check oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "exits 0 against the real repo" {
  cd "${REAL_REPO_DIR}"
  run "${CHECK}"
  assert_success
}
