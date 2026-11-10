bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # Captured before the cd: common.bash resolves REPO_DIR from BATS_TEST_DIRNAME.
  CHECK="${REPO_DIR}/check-scripts"
  # The relative path arguments below name files in the repo, and bats does not
  # guarantee a CWD. Pin it.
  cd "${REPO_DIR}" || return 1
  load '../test_helper/devshell_nix'
  devshell_nix::setup
}

# check-scripts always runs the two whole-repo audits regardless of its
# arguments, so its EXIT CODE depends on working-tree state, not just on the
# argument under test. Every assertion below is therefore on output content.

@test "check-scripts: a markdown argument is not parsed as shell" {
  local -r doc="${BATS_TEST_TMPDIR}/notes.md"
  printf '%s\n' '# Title' '' 'Prose with (parentheses) that shfmt would reject.' > "${doc}"

  run "${CHECK}" "${doc}"

  # The regression itself: shfmt must never see this file.
  refute_output --partial 'a command can only contain words and redirects'
  # ...and it must be visibly skipped rather than silently vanishing.
  assert_output --partial 'Skipping (not a shell file)'
}

@test "check-scripts: a misformatted shell file still reaches shfmt" {
  # Guards the other direction: the new filter must not smuggle real shell
  # files past the formatting gate. It is only misformatted, not unsound —
  # shfmt is the only step that can report it, since shellcheck passes it clean.
  local -r script="${BATS_TEST_TMPDIR}/bad.bash"
  printf '%s\n' 'if true; then' 'echo "unindented"' 'fi' > "${script}"

  run "${CHECK}" "${script}"

  assert_output --partial "${script}"
}

@test "check-scripts: --help exits 0 and prints help text" {
  run "${CHECK}" --help
  assert_success
  assert_output --partial 'shellcheck'
}

@test "check-scripts: dies when a path does not exist" {
  run "${CHECK}" "${BATS_TEST_TMPDIR}/no-such-file.bash"
  assert_failure
  assert_output --partial 'does not exist'
}

@test "check-scripts: a misformatted file fails the run" {
  # assert_failure is safe despite the whole-repo audits: rc only ever goes
  # 0 -> 1, so a real shfmt failure pins exit 1 whatever the tree state.
  local -r script="${BATS_TEST_TMPDIR}/bad.bash"
  printf '%s\n' 'if true; then' 'echo "unindented"' 'fi' > "${script}"

  run "${CHECK}" "${script}"

  assert_failure
}

@test "check-scripts: a shellcheck violation fails the run" {
  local -r script="${BATS_TEST_TMPDIR}/sc.bash"
  # shellcheck disable=SC2016 # the unexpanded $unquoted IS the fixture's shellcheck violation
  printf '%s\n' '#!/usr/bin/env bash' 'echo $unquoted' > "${script}"

  run "${CHECK}" "${script}"

  assert_failure
  assert_output --partial 'SC2086'
}

@test "check-scripts: shfmt and shellcheck failures are BOTH reported in one run" {
  # The aggregation contract. check-scripts collects rc across four tools rather
  # than failing fast, so a shfmt failure must not stop shellcheck from running.
  # Asserting on output rather than exit code: exit 1 alone cannot distinguish
  # "both ran" from "aborted at the first failure".
  local -r misformatted="${BATS_TEST_TMPDIR}/bad.bash"
  local -r unsound="${BATS_TEST_TMPDIR}/sc.bash"
  printf '%s\n' 'if true; then' 'echo "unindented"' 'fi' > "${misformatted}"
  # shellcheck disable=SC2016 # the unexpanded $unquoted IS the fixture's shellcheck violation
  printf '%s\n' '#!/usr/bin/env bash' 'echo $unquoted' > "${unsound}"

  run "${CHECK}" "${misformatted}" "${unsound}"

  assert_failure
  # shfmt's finding...
  assert_output --partial "${misformatted}"
  # ...and shellcheck's, from the same invocation.
  assert_output --partial 'SC2086'
}

@test "check-scripts: a file under other/ is not format-checked" {
  # Third-party code is never reformatted. Two independent guards must hold: the
  # shfmt loop skips */other/* outright, and shell_scripts::filter gates other/
  # behind prompt::ny before shellcheck sees it. SCRIPTS_AUTO_ANSWER=y makes that
  # prompt take its default (no) without reading stdin -- without it the prompt
  # blocks forever under BATS, where stdin is not a TTY but never reaches EOF.
  #
  # The control for this test is "a misformatted file fails the run" above: the
  # same content outside other/ is reported, so silence here is the other/ skip
  # and not an inert fixture.
  local -r other_dir="${BATS_TEST_TMPDIR}/other"
  mkdir --parents "${other_dir}"
  local -r script="${other_dir}/third-party.bash"
  printf '%s\n' 'if true; then' 'echo "unindented"' 'fi' > "${script}"

  SCRIPTS_AUTO_ANSWER=y run "${CHECK}" "${script}"

  # shfmt would print a unified diff naming the file; it must not.
  refute_output --partial '+++ '
  refute_output --partial 'third-party.bash'
}

@test "check-scripts: a directory holding no shell files reports nothing" {
  # The empty-candidates early exit. Nothing to format or lint, so neither tool
  # may report on it -- and the run must not treat an empty arg scan as a crash.
  local -r empty_dir="${BATS_TEST_TMPDIR}/empty"
  mkdir --parents "${empty_dir}"
  printf '%s\n' 'not a shell script' > "${empty_dir}/README.md"

  run "${CHECK}" "${empty_dir}"

  refute_output --partial '+++ '
  refute_output --partial 'SC2'
}

# The self-wrap cases: a direct run from a shell outside the devShell re-runs the
# script through .ci/in-devshell. devshell_nix::run_outside starts it the way such
# a shell would, against the stub nix (see devshell_nix.bash).

@test "self-wrap: a direct run re-runs itself inside the devShell, with the host PATH gone" {
  devshell_nix::install_emulator
  cd "${REPO_DIR}" || return 1
  run devshell_nix::run_outside "${REPO_DIR}/check-scripts" --help
  assert_success
  assert_output --partial 'shellcheck'
  devshell_nix::assert_reran "${REPO_REAL}/check-scripts" --help
  devshell_nix::assert_in_devshell
  devshell_nix::assert_scratch_empty
}

@test "self-wrap: arguments and exit status survive the re-run" {
  devshell_nix::install_recorder 7
  cd "${REPO_DIR}" || return 1
  run devshell_nix::run_outside "${REPO_DIR}/check-scripts" 'a b' '' '*'
  assert_failure 7
  devshell_nix::assert_reran "${REPO_REAL}/check-scripts" 'a b' '' '*'
  devshell_nix::assert_scratch_empty
}

@test "self-wrap: a run through a symlink from the repo root hands itself to the devShell" {
  devshell_nix::install_recorder 5
  ln --symbolic -- "${REPO_DIR}/check-scripts" "${BATS_TEST_TMPDIR}/link"
  cd "${REPO_DIR}" || return 1
  run devshell_nix::run_outside "${BATS_TEST_TMPDIR}/link" 'x'
  assert_failure 5
  devshell_nix::assert_reran "${REPO_REAL}/check-scripts" 'x'
  devshell_nix::assert_in_devshell
  devshell_nix::assert_scratch_empty
}

@test "self-wrap: a run through a symlink from outside any repo hands itself to the devShell" {
  devshell_nix::install_recorder 6
  mkdir -- "${BATS_TEST_TMPDIR}/elsewhere"
  ln --symbolic -- "${REPO_DIR}/check-scripts" "${BATS_TEST_TMPDIR}/elsewhere/link"
  cd "${BATS_TEST_TMPDIR}/elsewhere" || return 1
  run devshell_nix::run_outside "${BATS_TEST_TMPDIR}/elsewhere/link" 'y'
  assert_failure 6
  devshell_nix::assert_reran "${REPO_REAL}/check-scripts" 'y'
  devshell_nix::assert_in_devshell
  devshell_nix::assert_scratch_empty
}

@test "self-wrap: with IN_DEVSHELL already set there is no re-run" {
  devshell_nix::install_recorder 42
  cd "${REPO_DIR}" || return 1
  run env IN_DEVSHELL=1 PATH="${HOST_DIR}:${NIX_STUB_DIR}:${PATH}" TMPDIR="${NIX_SCRATCH}" \
    "${REPO_DIR}/check-scripts" --help
  assert_success
  assert_output --partial 'shellcheck'
  assert [ ! -e "${NIX_ARGS_FILE}" ]
}
