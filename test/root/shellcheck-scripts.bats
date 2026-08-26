bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  SCRIPT="${REPO_DIR}/shellcheck-scripts"
  # The runner resolves nothing from CWD, but shell_scripts::find shells out to
  # shfmt for directory args; pin CWD for determinism. (Do not start this comment
  # with the tool's own name — shellcheck parses "# shellcheck..." as a directive.)
  cd "${REPO_DIR}" || return 1
}

# Write content to a fixture file under the per-test tmpdir and echo its path.
make_file() {
  local -r name="$1"
  local -r content="$2"
  printf '%s' "${content}" > "${BATS_TEST_TMPDIR}/${name}"
  printf '%s\n' "${BATS_TEST_TMPDIR}/${name}"
}

@test "a clean script passes" {
  local target
  target="$(make_file 'clean' '#!/usr/bin/env bash
printf "%s\n" "hello"
')"
  run "${SCRIPT}" "${target}"
  assert_success
}

@test "a script with a shellcheck violation fails and names the file" {
  # SC2086: unquoted variable expansion.
  local target
  # shellcheck disable=SC2016 # the literal $var is fixture content, not an expansion
  target="$(make_file 'dirty' '#!/usr/bin/env bash
var="a b"
printf "%s\n" $var
')"
  run "${SCRIPT}" "${target}"
  assert_failure
  assert_output --partial "${target}"
}

@test "a file with no shell shebang is filtered out" {
  local target
  target="$(make_file 'notes.txt' 'Prose with (parentheses) shellcheck would reject.
')"
  run "${SCRIPT}" "${target}"
  assert_success
}

@test "a nonexistent path dies" {
  run "${SCRIPT}" "${BATS_TEST_TMPDIR}/absent"
  assert_failure
  assert_output --partial 'does not exist'
}

@test "--help exits 0" {
  run "${SCRIPT}" --help
  assert_success
}

# Unlike the .ci/ gates, whose absent-scan-target guards were removed in #323 as
# silent false greens, an explicitly-passed directory that holds no shell files is a
# request the caller actually made, not a misdirected scan. The no-args form is still
# protected — shell_scripts::find exits 1 on an empty match there.
@test "an explicitly passed directory with no shell files is a clean no-op" {
  local -r empty_dir="${BATS_TEST_TMPDIR}/no-shell"
  mkdir --parents "${empty_dir}"
  printf 'not a script\n' > "${empty_dir}/notes.txt"
  run "${SCRIPT}" "${empty_dir}"
  assert_success
}
