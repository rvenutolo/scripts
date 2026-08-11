# shellcheck disable=SC2030,SC2031 # BATS runs each @test in a subshell; REQUIRED_TOOLS_OVERRIDE mutations are intentional and correctly scoped per-test

setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  CHECK="${REPO_DIR}/.ci/check-devshell-provides"
  # The shipped REQUIRED_TOOLS names real devShell binaries. Tests drive a
  # synthetic list instead so they assert the lint's logic, not the machine's
  # toolchain — except the one that deliberately pins the real defaults.
  export REQUIRED_TOOLS_OVERRIDE='faketool'
}

# path_shim::add wants a body with a shebang. The shims are never executed —
# the lint only resolves their paths — so a no-op body is enough.
add_tool_shim() {
  path_shim::add "$1" '#!/usr/bin/env bash
true'
}

@test "passes when the tool resolves outside HOME" {
  add_tool_shim 'faketool'
  run "${CHECK}"
  assert_success
}

@test "fails when the tool is absent from PATH" {
  export REQUIRED_TOOLS_OVERRIDE='definitely-not-a-real-tool-xyz123'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'definitely-not-a-real-tool-xyz123'
  assert_output --partial 'not found'
}

@test "names flake.nix in the not-found message" {
  export REQUIRED_TOOLS_OVERRIDE='definitely-not-a-real-tool-xyz123'
  run "${CHECK}"
  assert_output --partial 'flake.nix'
}

@test "fails when the tool resolves from under HOME" {
  # path_shim writes into ${BATS_TEST_TMPDIR}/bin; pointing HOME at that tmpdir
  # makes the shim look exactly like a ~/.nix-profile binary, which is the
  # failure #219 describes.
  add_tool_shim 'faketool'
  HOME="${BATS_TEST_TMPDIR}" run "${CHECK}"
  assert_failure
  assert_output --partial 'faketool'
  # shellcheck disable=SC2016 # '$HOME' is literal text the lint under test emits, never an expansion
  assert_output --partial 'under $HOME'
}

@test "reports every failing tool, not just the first" {
  export REQUIRED_TOOLS_OVERRIDE='missing-one-xyz missing-two-xyz'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'missing-one-xyz'
  assert_output --partial 'missing-two-xyz'
}

@test "passes with multiple resolvable tools" {
  add_tool_shim 'faketool'
  add_tool_shim 'othertool'
  export REQUIRED_TOOLS_OVERRIDE='faketool othertool'
  run "${CHECK}"
  assert_success
}

@test "passes with an empty tool list" {
  export REQUIRED_TOOLS_OVERRIDE=''
  run "${CHECK}"
  assert_success
}

@test "rejects an unexpected argument" {
  add_tool_shim 'faketool'
  run "${CHECK}" unexpected
  assert_failure
}

@test "--help exits 0 and prints the description" {
  run "${CHECK}" --help
  assert_success
  assert_output --partial 'devShell'
}

@test "the shipped tool list resolves in the real devShell" {
  unset REQUIRED_TOOLS_OVERRIDE
  run "${CHECK}"
  assert_success
}
