#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # Captured before the cd: common.bash resolves REPO_DIR from BATS_TEST_DIRNAME.
  CHECK="${REPO_DIR}/check-scripts"
  # check-scripts derives its own repo root via `git rev-parse --show-toplevel`
  # from the CWD, and bats does not guarantee a CWD. Pin it.
  cd "${REPO_DIR}" || return 1
}

# check-scripts always runs the two whole-repo audits regardless of its
# arguments, so its EXIT CODE depends on working-tree state, not just on the
# argument under test. Every assertion below is therefore on output content.

@test "check-scripts: a markdown argument is not parsed as shell" {
  local -r doc="${BATS_TEST_TMPDIR}/notes.md"
  printf '%s\n' '# Title' '' 'Prose with (parentheses) that shfmt would reject.' > "${doc}"

  run "${CHECK}" "${doc}"

  # The regression itself: shfmt must never see this file. See issue #206.
  refute_output --partial 'a command can only contain words and redirects'
  # ...and it must be visibly skipped rather than silently vanishing.
  assert_output --partial 'Skipping (not a shell file)'
}

@test "check-scripts: a misformatted shell file still reaches shfmt" {
  # Guards the other direction: the new filter must not smuggle real shell
  # files past the formatting gate. No shebang, so the shellcheck step skips it
  # and shfmt is the only step that can report it.
  local -r script="${BATS_TEST_TMPDIR}/bad.bash"
  printf '%s\n' 'if true; then' 'echo "unindented"' 'fi' > "${script}"

  run "${CHECK}" "${script}"

  assert_output --partial "${script}"
}
