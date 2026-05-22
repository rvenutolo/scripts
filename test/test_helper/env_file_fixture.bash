#!/usr/bin/env bash

# Test helper: write env-file content to a per-test tmpfile and echo its path.
# Used by env_file.bats to set up fixtures cleanly. BATS_TEST_TMPDIR is auto-cleaned per test.
#
# $1 = file content (written verbatim via printf '%s')
# $2 = tmpfile basename (optional; default 'env')
# Output: stdout — absolute path of the created file
function env_file_fixture::create() {
  args::check_at_least_1_arg "$@"
  args::check_at_most_2_args "$@"
  local -r content="$1"
  local -r name="${2:-env}"
  local -r path="${BATS_TEST_TMPDIR}/${name}"
  printf '%s' "${content}" >"${path}"
  printf '%s' "${path}"
}
