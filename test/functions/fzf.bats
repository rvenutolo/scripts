#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  # shellcheck disable=SC1091 # resolved via SCRIPTS_DIR set by common.bash
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/fzf.bash"
}

# Write candidate lines to a per-test tmpfile and echo its path. Callers redirect
# the file into fzf::select as stdin (run executes in this shell, so the
# path_shim-mutated PATH is in effect and the stub fzf is found).
# $1 = candidate lines (printf format string)
function candidates_file() {
  local -r content="$1"
  printf '%b' "${content}" > "${BATS_TEST_TMPDIR}/candidates"
  printf '%s' "${BATS_TEST_TMPDIR}/candidates"
}

# ---------- fzf::select ----------

@test "select: passes the repo-standard flags to fzf" {
  # Stub fzf that echoes its own args, one per line.
  path_shim::add fzf $'#!/usr/bin/env bash\nprintf \'%s\\n\' "$@"'
  local -r in="$(candidates_file 'a\nb\n')"
  run fzf::select < "${in}"
  assert_success
  assert_line '--height=20'
  assert_line '--exact'
  assert_line '--layout=reverse'
}

@test "select: forwards extra args verbatim after the standard flags" {
  path_shim::add fzf $'#!/usr/bin/env bash\nprintf \'%s\\n\' "$@"'
  local -r in="$(candidates_file 'a\n')"
  run fzf::select --delimiter=$'\t' --with-nth=2.. < "${in}"
  assert_success
  assert_line '--with-nth=2..'
  # delimiter value is a literal tab character
  assert_line $'--delimiter=\t'
}

@test "select: standard flags precede extra args" {
  path_shim::add fzf $'#!/usr/bin/env bash\nprintf \'%s\\n\' "$@"'
  local -r in="$(candidates_file 'a\n')"
  run fzf::select --extra < "${in}"
  assert_success
  assert_line --index 0 '--height=20'
  assert_line --index 1 '--exact'
  assert_line --index 2 '--layout=reverse'
  assert_line --index 3 '--extra'
}

@test "select: stdin candidates reach fzf and the selection is echoed" {
  # Stub fzf that reads stdin and selects the first candidate line.
  path_shim::add fzf $'#!/usr/bin/env bash\nhead -1'
  local -r in="$(candidates_file 'first\nsecond\n')"
  run fzf::select < "${in}"
  assert_success
  assert_output 'first'
}

@test "select: aborting fzf propagates the non-zero exit status" {
  # Stub fzf that mimics an aborted picker.
  path_shim::add fzf $'#!/usr/bin/env bash\nexit 130'
  local -r in="$(candidates_file 'a\nb\n')"
  run fzf::select < "${in}"
  assert_failure 130
}

@test "select: accepts zero extra args" {
  path_shim::add fzf $'#!/usr/bin/env bash\nhead -1'
  local -r in="$(candidates_file 'only\n')"
  run fzf::select < "${in}"
  assert_success
  assert_output 'only'
}
