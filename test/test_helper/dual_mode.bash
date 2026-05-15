#!/usr/bin/env bash

# Test helpers for functions that accept input from EITHER stdin OR a file path.
# Used by tests for text::*, json::sort, and files::hash. NOT used by grep::*:
# those helpers are also dual-mode but take an extra pattern arg (1 arg = stdin
# + pattern; 2 args = file + pattern), so they need their own run wrappers in
# test/functions/grep.bats rather than these single-input helpers.
#
# Both helpers depend on bats-assert (loaded by test_helper/common.bash) and
# on the function under test having been sourced by the calling .bats file.

# Run a dual-mode function with input piped on stdin; assert success and output.
# $1 = function name (e.g. "text::first_line")
# $2 = input string (printed verbatim to the function's stdin via printf '%s')
# $3 = expected stdout
function dual_mode::assert_stdin() {
  local -r fn="$1"
  local -r input="$2"
  local -r expected="$3"
  run bash -c "source '${SCRIPTS_DIR}/functions.bash'; printf '%s' \"\$1\" | ${fn}" _ "${input}"
  assert_success
  assert_output "${expected}"
}

# Run a dual-mode function with input written to a per-test tmpfile and the
# tmpfile passed as $1 to the function. Asserts success and output.
# $1 = function name
# $2 = input string (written to tmpfile via printf '%s')
# $3 = expected stdout
function dual_mode::assert_file() {
  local -r fn="$1"
  local -r input="$2"
  local -r expected="$3"
  local -r tmp="${BATS_TEST_TMPDIR}/dual_mode_input"
  printf '%s' "${input}" > "${tmp}"
  run bash -c "source '${SCRIPTS_DIR}/functions.bash'; ${fn} \"\$1\"" _ "${tmp}"
  assert_success
  assert_output "${expected}"
}
