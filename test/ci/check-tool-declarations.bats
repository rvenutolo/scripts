# shellcheck disable=SC2030,SC2031 # BATS runs each @test in a subshell; the *_OVERRIDE mutations are intentional and correctly scoped per-test
# shellcheck disable=SC2016 # the $-expansions in fixture bodies are literal script text the lint must read, never expansions here

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  load '../test_helper/git_fixture'
  CHECK="${REPO_DIR}/.ci/check-tool-declarations"
  FIXTURE_CI="${BATS_TEST_TMPDIR}/ci"
  FIXTURE_HOOKS="${BATS_TEST_TMPDIR}/hooks"
  FIXTURE_ROOT="${BATS_TEST_TMPDIR}/root"
  mkdir --parents "${FIXTURE_CI}" "${FIXTURE_HOOKS}" "${FIXTURE_ROOT}"
  # The check resolves REPO_DIR via `git rev-parse --show-toplevel`, so it must run
  # with cwd inside a git repo or it exits 128 before any scan. common.bash leaves
  # cwd at BATS_TEST_TMPDIR, which is deliberately not a repo (#248 hardening), so
  # give the check a throwaway fixture repo to resolve. Only REPO_DIR resolution
  # depends on it — the three scan roots come from the overrides below.
  FIXTURE_REPO="${BATS_TEST_TMPDIR}/repo"
  git_fixture::init "${FIXTURE_REPO}"
  cd "${FIXTURE_REPO}" || return 1
  export CI_DIR_OVERRIDE="${FIXTURE_CI}"
  export HOOKS_DIR_OVERRIDE="${FIXTURE_HOOKS}"
  export ROOT_DIR_OVERRIDE="${FIXTURE_ROOT}"
  # An empty declared list and an empty exemption list by default: the shipped
  # values describe the real repo, and a fixture tree that neither names `nix` nor
  # ships a .ci/required-tools would read every shipped entry as stale.
  export REQUIRED_TOOLS_OVERRIDE=''
  export EXEMPT_TOOLS_OVERRIDE=''
}

# Write an executable fixture script whose body is the given lines.
write_script() {
  local -r path="$1"
  shift
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' "$@"
  } > "${path}"
  chmod +x "${path}"
}

# Write a required-tools-shaped data file and point the check at it. Callers that
# use this must also unset REQUIRED_TOOLS_OVERRIDE, which short-circuits the file.
write_tools_file() {
  local -r path="${BATS_TEST_TMPDIR}/required-tools"
  printf '%s\n' "$@" > "${path}"
  export REQUIRED_TOOLS_FILE_OVERRIDE="${path}"
}

@test "passes on a clean .ci fixture" {
  write_script "${FIXTURE_CI}/clean" 'echo hi'
  run "${CHECK}"
  assert_success
}

@test "passes on an empty scope" {
  run "${CHECK}"
  assert_success
}

@test "fails on a single-quoted call naming an undeclared tool" {
  write_script "${FIXTURE_CI}/lint" "commands::assert_executable_exists 'ripgrep'"
  run "${CHECK}"
  assert_failure
  assert_output --partial 'ripgrep is not declared in .ci/required-tools'
}

@test "passes when the named tool is declared" {
  write_script "${FIXTURE_CI}/lint" "commands::assert_executable_exists 'ripgrep'"
  export REQUIRED_TOOLS_OVERRIDE='ripgrep'
  run "${CHECK}"
  assert_success
}

@test "reads a double-quoted literal argument" {
  write_script "${FIXTURE_CI}/lint" 'commands::assert_executable_exists "ripgrep"'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'ripgrep'
}

@test "reads a bare unquoted argument" {
  write_script "${FIXTURE_CI}/lint" 'commands::assert_executable_exists ripgrep'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'ripgrep'
}

@test "reads the non-asserting predicate form" {
  write_script "${FIXTURE_CI}/lint" "if ! commands::executable_exists 'ripgrep'; then" '  exit 1' 'fi'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'ripgrep'
}

@test "ignores a variable argument rather than flagging it" {
  write_script "${FIXTURE_CI}/lint" 'commands::assert_executable_exists "${tool}"'
  run "${CHECK}"
  assert_success
}

@test "ignores an unquoted variable argument" {
  write_script "${FIXTURE_CI}/lint" 'commands::assert_executable_exists $tool'
  run "${CHECK}"
  assert_success
}

@test "ignores a call named only in a comment" {
  write_script "${FIXTURE_CI}/lint" "# commands::assert_executable_exists 'ripgrep' would do it"
  run "${CHECK}"
  assert_success
}

@test "ignores a different function with a similar name" {
  write_script "${FIXTURE_CI}/lint" 'commands::executable_path "ripgrep"'
  run "${CHECK}"
  assert_success
}

@test "flags a call site under .githooks" {
  write_script "${FIXTURE_HOOKS}/pre-push" "commands::assert_executable_exists 'ripgrep'"
  run "${CHECK}"
  assert_failure
  assert_output --partial 'pre-push'
  assert_output --partial 'ripgrep'
}

@test "flags a call site in a repo-root runner" {
  write_script "${FIXTURE_ROOT}/some-runner" "commands::assert_executable_exists 'ripgrep'"
  run "${CHECK}"
  assert_failure
  assert_output --partial 'some-runner'
}

@test "reports the offending line number" {
  write_script "${FIXTURE_CI}/lint" 'echo one' "commands::assert_executable_exists 'ripgrep'"
  run "${CHECK}"
  assert_failure
  assert_output --partial ':3: ripgrep'
}

@test "reports every undeclared tool, not just the first" {
  write_script "${FIXTURE_CI}/lint" \
    "commands::assert_executable_exists 'ripgrep'" \
    "commands::assert_executable_exists 'fdfind'"
  run "${CHECK}"
  assert_failure
  assert_output --partial 'ripgrep'
  assert_output --partial 'fdfind'
}

@test "reports only the undeclared tool when another is declared" {
  write_script "${FIXTURE_CI}/lint" \
    "commands::assert_executable_exists 'ripgrep'" \
    "commands::assert_executable_exists 'fdfind'"
  export REQUIRED_TOOLS_OVERRIDE='ripgrep'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'fdfind'
  refute_output --partial 'ripgrep is not declared'
}

@test "an EXEMPT_TOOLS entry suppresses an undeclared call site" {
  write_script "${FIXTURE_CI}/lint" "commands::assert_executable_exists 'ripgrep'"
  export EXEMPT_TOOLS_OVERRIDE='ripgrep'
  run "${CHECK}"
  assert_success
}

@test "fails when an EXEMPT_TOOLS entry is named by no call site" {
  write_script "${FIXTURE_CI}/clean" 'echo hi'
  export EXEMPT_TOOLS_OVERRIDE='ripgrep'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'stale EXEMPT_TOOLS entry: ripgrep is named by no call site'
}

@test "fails when an EXEMPT_TOOLS entry is also declared" {
  write_script "${FIXTURE_CI}/lint" "commands::assert_executable_exists 'ripgrep'"
  export REQUIRED_TOOLS_OVERRIDE='ripgrep'
  export EXEMPT_TOOLS_OVERRIDE='ripgrep'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'stale EXEMPT_TOOLS entry: ripgrep is declared'
}

@test "reads the declared list from the required-tools data file" {
  write_script "${FIXTURE_CI}/lint" "commands::assert_executable_exists 'ripgrep'"
  unset REQUIRED_TOOLS_OVERRIDE
  write_tools_file '# a comment' '' 'ripgrep' '# another comment'
  run "${CHECK}"
  assert_success
}

@test "strips a trailing comment from a data-file entry" {
  write_script "${FIXTURE_CI}/lint" "commands::assert_executable_exists 'ripgrep'"
  unset REQUIRED_TOOLS_OVERRIDE
  write_tools_file 'ripgrep # used by the fixture lint'
  run "${CHECK}"
  assert_success
}

@test "a commented-out data-file entry does not declare the tool" {
  write_script "${FIXTURE_CI}/lint" "commands::assert_executable_exists 'ripgrep'"
  unset REQUIRED_TOOLS_OVERRIDE
  write_tools_file '# ripgrep'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'ripgrep is not declared'
}

@test "dies when the required-tools data file is missing" {
  write_script "${FIXTURE_CI}/lint" 'echo hi'
  unset REQUIRED_TOOLS_OVERRIDE
  export REQUIRED_TOOLS_FILE_OVERRIDE="${BATS_TEST_TMPDIR}/no-such-file"
  run "${CHECK}"
  assert_failure
  assert_output --partial 'no-such-file does not exist'
}

@test "does not flag its own source" {
  # The gawk program spells the function names with bracketed colons and
  # underscores so the lint cannot read itself as a call site. The only tool this
  # script legitimately names is gawk, which it asserts at the top.
  cp "${CHECK}" "${FIXTURE_CI}/check-tool-declarations"
  run "${CHECK}"
  assert_failure
  assert_output --partial 'gawk is not declared'
  assert_equal "$(printf '%s\n' "${output}" | grep --count 'is not declared')" '1'
}

@test "passes over its own source once gawk is declared" {
  cp "${CHECK}" "${FIXTURE_CI}/check-tool-declarations"
  export REQUIRED_TOOLS_OVERRIDE='gawk'
  run "${CHECK}"
  assert_success
}

@test "passes on the real repo tree" {
  # The shipped scope, declared list, and exemptions — not the fixture. This is
  # the assertion that the invariant actually holds in this repo, so it must be
  # driven with the real defaults rather than the overrides above.
  unset CI_DIR_OVERRIDE HOOKS_DIR_OVERRIDE ROOT_DIR_OVERRIDE
  unset REQUIRED_TOOLS_OVERRIDE EXEMPT_TOOLS_OVERRIDE REQUIRED_TOOLS_FILE_OVERRIDE
  cd "${REPO_DIR}" || return 1
  run "${CHECK}"
  assert_success
}

@test "dies when given an argument" {
  run "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "prints help and exits 0 for --help" {
  run "${CHECK}" --help
  assert_success
  assert_output --partial 'required-tools'
}
