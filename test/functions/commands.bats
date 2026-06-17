#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/test/test_helper/path_shim.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/path.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/commands.bash"

  # Redirect SCRIPTS_DIR to a tmpdir so commands::* strips tmpdir wrappers
  # rather than the real repo's interactive/, non-interactive/, and other/.
  export REAL_SCRIPTS_DIR="${SCRIPTS_DIR}"
  SCRIPTS_DIR="${BATS_TEST_TMPDIR}"
  mkdir --parents "${SCRIPTS_DIR}/interactive" "${SCRIPTS_DIR}/non-interactive" "${SCRIPTS_DIR}/other"
}

# ---------- commands::executable_exists ----------

@test "executable_exists: real bin in tmp PATH -> true" {
  path_shim::add 'fake_bin_xyz' '#!/usr/bin/env bash
echo real'
  run commands::executable_exists 'fake_bin_xyz'
  assert_success
}

@test "executable_exists: nonexistent name -> false" {
  run commands::executable_exists 'definitely-not-a-real-cmd-xyz123'
  assert_failure
}

@test "executable_exists: wrapper in interactive/ ignored, real in PATH -> true" {
  printf '%s\n' '#!/usr/bin/env bash' 'echo wrapper' > "${SCRIPTS_DIR}/interactive/foo_wrapper_xyz"
  chmod +x "${SCRIPTS_DIR}/interactive/foo_wrapper_xyz"
  path_shim::add 'foo_wrapper_xyz' '#!/usr/bin/env bash
echo real'
  # PATH mutation is intentional: BATS subshell isolates it; run inherits the updated PATH
  # shellcheck disable=SC2030,SC2031
  PATH="${SCRIPTS_DIR}/interactive:${PATH}"
  run commands::executable_exists 'foo_wrapper_xyz'
  assert_success
}

@test "executable_exists: only wrapper in interactive/, no real -> false" {
  printf '%s\n' '#!/usr/bin/env bash' 'echo wrapper' > "${SCRIPTS_DIR}/interactive/only_wrapper_xyz"
  chmod +x "${SCRIPTS_DIR}/interactive/only_wrapper_xyz"
  # PATH mutation is intentional: BATS subshell isolates it; run inherits the updated PATH
  # shellcheck disable=SC2030,SC2031
  PATH="${SCRIPTS_DIR}/interactive:${PATH}"
  run commands::executable_exists 'only_wrapper_xyz'
  assert_failure
}

@test "executable_exists: only wrapper in non-interactive/, no real -> false" {
  printf '%s\n' '#!/usr/bin/env bash' 'echo wrapper' > "${SCRIPTS_DIR}/non-interactive/noninteractive_wrapper_xyz"
  chmod +x "${SCRIPTS_DIR}/non-interactive/noninteractive_wrapper_xyz"
  # PATH mutation is intentional: BATS subshell isolates it; run inherits the updated PATH
  # shellcheck disable=SC2030,SC2031
  PATH="${SCRIPTS_DIR}/non-interactive:${PATH}"
  run commands::executable_exists 'noninteractive_wrapper_xyz'
  assert_failure
}

@test "executable_exists: only wrapper in other/, no real -> false" {
  printf '%s\n' '#!/usr/bin/env bash' 'echo wrapper' > "${SCRIPTS_DIR}/other/other_wrapper_xyz"
  chmod +x "${SCRIPTS_DIR}/other/other_wrapper_xyz"
  # PATH mutation is intentional: BATS subshell isolates it; run inherits the updated PATH
  # shellcheck disable=SC2030,SC2031
  PATH="${SCRIPTS_DIR}/other:${PATH}"
  run commands::executable_exists 'other_wrapper_xyz'
  assert_failure
}

@test "executable_exists: dies with 0 args" {
  run commands::executable_exists
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "executable_exists: dies with 2 args" {
  run commands::executable_exists 'a' 'b'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- commands::executable_path ----------

@test "executable_path: real bin -> prints absolute path" {
  path_shim::add 'fake_bin_path_xyz' '#!/usr/bin/env bash
echo real'
  run commands::executable_path 'fake_bin_path_xyz'
  assert_success
  assert_output "${BATS_TEST_TMPDIR}/bin/fake_bin_path_xyz"
}

@test "executable_path: nonexistent -> empty stdout, nonzero exit" {
  run commands::executable_path 'definitely-not-a-real-cmd-xyz123'
  assert_failure
  assert_output ''
}

@test "executable_path: wrapper in interactive/ skipped, returns real" {
  printf '%s\n' '#!/usr/bin/env bash' 'echo wrapper' > "${SCRIPTS_DIR}/interactive/path_wrapper_xyz"
  chmod +x "${SCRIPTS_DIR}/interactive/path_wrapper_xyz"
  path_shim::add 'path_wrapper_xyz' '#!/usr/bin/env bash
echo real'
  # PATH mutation is intentional: BATS subshell isolates it; run inherits the updated PATH
  # shellcheck disable=SC2031
  PATH="${SCRIPTS_DIR}/interactive:${PATH}"
  run commands::executable_path 'path_wrapper_xyz'
  assert_success
  assert_output "${BATS_TEST_TMPDIR}/bin/path_wrapper_xyz"
}

@test "executable_path: dies with 0 args" {
  run commands::executable_path
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "executable_path: dies with 2 args" {
  run commands::executable_path 'a' 'b'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- commands::assert_executable_exists ----------

@test "assert_executable_exists: existing executable -> returns 0 silently" {
  path_shim::add 'fake_assert_bin_xyz' '#!/usr/bin/env bash
echo real'
  run commands::assert_executable_exists 'fake_assert_bin_xyz'
  assert_success
  assert_output ''
}

@test "assert_executable_exists: missing executable -> exits non-zero" {
  run commands::assert_executable_exists 'definitely-not-a-real-cmd-xyz123'
  assert_failure
}

@test "assert_executable_exists: missing executable -> stderr contains executable name" {
  run commands::assert_executable_exists 'definitely-not-a-real-cmd-xyz123'
  assert_failure
  assert_output --partial 'definitely-not-a-real-cmd-xyz123'
}

@test "assert_executable_exists: missing executable -> stderr contains 'not found'" {
  run commands::assert_executable_exists 'definitely-not-a-real-cmd-xyz123'
  assert_failure
  assert_output --partial 'not found'
}

@test "assert_executable_exists: missing executable -> stderr contains caller context from log::die" {
  run commands::assert_executable_exists 'definitely-not-a-real-cmd-xyz123'
  assert_failure
  assert_output --partial 'commands::assert_executable_exists'
}

@test "assert_executable_exists: dies with 0 args" {
  run commands::assert_executable_exists
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "assert_executable_exists: dies with 2 args" {
  run commands::assert_executable_exists 'a' 'b'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- commands::function_exists ----------

@test "function_exists: defined function -> true" {
  function _test_helper_fn_xyz() { :; }
  run commands::function_exists '_test_helper_fn_xyz'
  assert_success
}

@test "function_exists: undefined name -> false" {
  run commands::function_exists '_definitely_not_defined_xyz'
  assert_failure
}

@test "function_exists: external bin name -> false" {
  run commands::function_exists 'ls'
  assert_failure
}

@test "function_exists: builtin name -> false" {
  run commands::function_exists 'cd'
  assert_failure
}

@test "function_exists: dies with 0 args" {
  run commands::function_exists
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "function_exists: dies with 2 args" {
  run commands::function_exists 'a' 'b'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}
