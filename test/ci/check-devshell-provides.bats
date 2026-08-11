# shellcheck disable=SC2030,SC2031 # BATS runs each @test in a subshell; REQUIRED_TOOLS_OVERRIDE and DEVSHELL_PATH_OVERRIDE mutations are intentional and correctly scoped per-test

setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  load '../test_helper/git_fixture'
  CHECK="${REPO_DIR}/.ci/check-devshell-provides"
  # The check resolves REPO_DIR via `git rev-parse --show-toplevel`, so it must
  # run with cwd inside a git repo or it exits 128 before any scan. common.bash
  # leaves cwd at BATS_TEST_TMPDIR, which is deliberately not a repo (#248
  # hardening), so give the check a throwaway fixture repo to resolve. Only
  # REPO_DIR resolution depends on it — the devShell PATH comes from the
  # override below, which short-circuits the `nix print-dev-env` query.
  FIXTURE_REPO="${BATS_TEST_TMPDIR}/repo"
  git_fixture::init "${FIXTURE_REPO}"
  cd "${FIXTURE_REPO}" || return 1
  # A fake devShell PATH: tests populate it per case so they assert the lint's
  # logic rather than the machine's toolchain. This narrows common.bash's
  # suite-wide default from the ambient PATH to a directory this file controls.
  DEVSHELL_BIN="${BATS_TEST_TMPDIR}/devshell-bin"
  mkdir --parents "${DEVSHELL_BIN}"
  export DEVSHELL_PATH_OVERRIDE="${DEVSHELL_BIN}"
  # The shipped REQUIRED_TOOLS names real devShell binaries. Tests drive a
  # synthetic list instead, for the same reason.
  export REQUIRED_TOOLS_OVERRIDE='faketool'
}

# path_shim::add wants a body with a shebang. The shims are never executed —
# the lint only tests for their presence — so a no-op body is enough.
add_tool_shim() {
  path_shim::add "$1" '#!/usr/bin/env bash
true'
}

# Drop an executable of the given name into a fake devShell PATH directory
# (default: the one the setup exports).
add_devshell_tool() {
  local -r name="$1"
  local -r dir="${2:-${DEVSHELL_BIN}}"
  mkdir --parents "${dir}"
  printf '%s\n' '#!/usr/bin/env bash' 'true' > "${dir}/${name}"
  chmod +x "${dir}/${name}"
}

@test "passes when the tool is in the devShell PATH" {
  add_devshell_tool 'faketool'
  run "${CHECK}"
  assert_success
}

@test "fails when the tool is on the ambient PATH but not in the devShell PATH" {
  # #228 verbatim: a direnv-activated shell's ambient PATH still carries the
  # PREVIOUS devShell's store paths, so a tool deleted from flake.nix keeps
  # resolving. Membership in the devShell's OWN PATH is the only question that
  # matters, and this case passed under the PATH-based lint that shipped.
  add_tool_shim 'faketool'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'faketool'
  assert_output --partial 'not provided by the flake devShell'
  assert_output --partial 'flake.nix'
}

@test "fails when the tool is provided from under HOME" {
  # path_shim writes into ${BATS_TEST_TMPDIR}/bin; pointing HOME at that tmpdir
  # makes the shim look exactly like a ~/.nix-profile binary, which is the
  # failure #219 describes. The dedicated $HOME branch is gone — such a tool is
  # absent from the devShell PATH, so the closure check subsumes it (#228).
  add_tool_shim 'faketool'
  HOME="${BATS_TEST_TMPDIR}" run "${CHECK}"
  assert_failure
  assert_output --partial 'faketool'
  assert_output --partial 'not provided by the flake devShell'
}

@test "fails when the tool exists nowhere at all" {
  export REQUIRED_TOOLS_OVERRIDE='definitely-not-a-real-tool-xyz123'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'definitely-not-a-real-tool-xyz123'
  assert_output --partial 'not provided by the flake devShell'
}

@test "names flake.nix devShells.default.packages in the failure message" {
  export REQUIRED_TOOLS_OVERRIDE='definitely-not-a-real-tool-xyz123'
  run "${CHECK}"
  assert_output --partial 'flake.nix devShells.default.packages'
}

@test "reports every failing tool, not just the first" {
  export REQUIRED_TOOLS_OVERRIDE='missing-one-xyz missing-two-xyz'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'missing-one-xyz'
  assert_output --partial 'missing-two-xyz'
}

@test "passes with multiple tools, all in the devShell PATH" {
  add_devshell_tool 'faketool'
  add_devshell_tool 'othertool'
  export REQUIRED_TOOLS_OVERRIDE='faketool othertool'
  run "${CHECK}"
  assert_success
}

@test "reports only the tool missing from the devShell PATH" {
  add_devshell_tool 'faketool'
  export REQUIRED_TOOLS_OVERRIDE='faketool othertool'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'othertool'
  refute_output --partial 'faketool:'
}

@test "searches every directory on the devShell PATH" {
  local -r second="${BATS_TEST_TMPDIR}/devshell-bin2"
  add_devshell_tool 'faketool' "${second}"
  export DEVSHELL_PATH_OVERRIDE="${DEVSHELL_BIN}:${second}"
  run "${CHECK}"
  assert_success
}

@test "ignores empty entries on the devShell PATH" {
  add_devshell_tool 'faketool'
  export DEVSHELL_PATH_OVERRIDE=":${DEVSHELL_BIN}:"
  run "${CHECK}"
  assert_success
}

@test "fails when the devShell PATH entry is not executable" {
  printf '%s\n' 'not executable' > "${DEVSHELL_BIN}/faketool"
  chmod -x "${DEVSHELL_BIN}/faketool"
  run "${CHECK}"
  assert_failure
  assert_output --partial 'faketool'
}

@test "fails when the devShell PATH entry is a directory" {
  mkdir --parents "${DEVSHELL_BIN}/faketool"
  run "${CHECK}"
  assert_failure
  assert_output --partial 'faketool'
}

@test "fails when the devShell PATH is empty" {
  export DEVSHELL_PATH_OVERRIDE=''
  add_tool_shim 'faketool'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'faketool'
}

@test "passes with an empty tool list" {
  export REQUIRED_TOOLS_OVERRIDE=''
  run "${CHECK}"
  assert_success
}

@test "passes with an empty tool list and an empty devShell PATH" {
  export REQUIRED_TOOLS_OVERRIDE=''
  export DEVSHELL_PATH_OVERRIDE=''
  run "${CHECK}"
  assert_success
}

@test "rejects an unexpected argument" {
  add_devshell_tool 'faketool'
  run "${CHECK}" unexpected
  assert_failure
}

@test "--help exits 0 and prints the description" {
  run "${CHECK}" --help
  assert_success
  assert_output --partial 'devShell'
}

# There is deliberately no case here that unsets DEVSHELL_PATH_OVERRIDE to query the real
# devShell. Doing so shells out to `nix`, which needs the network, takes seconds, and — as
# this file's first CI run proved — writes nix/sentry/settings.dat into the working tree,
# failing run-lint-checks.bats in the process. See the DEVSHELL_PATH_OVERRIDE block in
# test_helper/common.bash. The real devShell is asserted by the `governance` CI job and by
# ./run-all-checks, both of which run this lint in an unmodified environment.
