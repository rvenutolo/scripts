# shellcheck disable=SC2016 # fixture bodies are literal shell text the lint reads, never expansions
# shellcheck disable=SC2030,SC2031 # BATS isolates each @test in its own subshell
bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  load '../test_helper/git_fixture'
  CHECK="${REPO_DIR}/.ci/check-hooks-path-single-writer"
  FIXTURE_CI="${BATS_TEST_TMPDIR}/ci"
  FIXTURE_HOOKS="${BATS_TEST_TMPDIR}/hooks"
  FIXTURE_ROOT="${BATS_TEST_TMPDIR}/root"
  FIXTURE_FLAKE="${BATS_TEST_TMPDIR}/flake.nix"
  mkdir -p "${FIXTURE_CI}" "${FIXTURE_HOOKS}" "${FIXTURE_ROOT}"
  # The check resolves REPO_DIR via `git rev-parse --show-toplevel`, so it must
  # run with cwd inside a git repo or it exits 128 before any scan. common.bash
  # leaves cwd at BATS_TEST_TMPDIR, which is deliberately not a repo
  # (fixture-escape hardening), so give it a throwaway fixture repo. Only
  # REPO_DIR resolution depends on it — every scan root comes from an override.
  FIXTURE_REPO="${BATS_TEST_TMPDIR}/repo"
  git_fixture::init "${FIXTURE_REPO}"
  cd "${FIXTURE_REPO}" || return 1
  export EXEMPT_OVERRIDE=''
  export CI_DIR_OVERRIDE="${FIXTURE_CI}"
  export HOOKS_DIR_OVERRIDE="${FIXTURE_HOOKS}"
  export ROOT_DIR_OVERRIDE="${FIXTURE_ROOT}"
  export FLAKE_NIX_OVERRIDE="${FIXTURE_FLAKE}"
  # The fixture tree is outside REPO_DIR, so the check's repo-relative strip is a
  # no-op there and paths stay absolute. The sanctioned-writer constant is
  # compared against that same post-strip path, so it is given absolutely here.
  SANCTIONED="${FIXTURE_CI}/activate-githooks"
  export SANCTIONED_WRITER_OVERRIDE="${SANCTIONED}"
  write_script "${SANCTIONED}" 'git config --local core.hooksPath ".githooks"'
  printf '%s\n' '{ inputs.nixpkgs.url = "x"; }' > "${FIXTURE_FLAKE}"
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

@test "passes when only the sanctioned writer sets the hook path" {
  run "${CHECK}"
  assert_success
}

@test "fails on a second writer under .ci" {
  write_script "${FIXTURE_CI}/rogue" 'git config --local core.hooksPath "/tmp/elsewhere"'
  run "${CHECK}"
  assert_failure 1
  assert_output --partial 'second writer of the hook path'
  assert_output --partial 'rogue'
}

@test "fails on a second writer under .githooks" {
  write_script "${FIXTURE_HOOKS}/pre-push" 'git config core.hooksPath "/tmp/elsewhere"'
  run "${CHECK}"
  assert_failure 1
  assert_output --partial 'pre-push'
}

@test "fails on a second writer among the root runners" {
  write_script "${FIXTURE_ROOT}/run-all-checks" 'git config core.hooksPath "/tmp/elsewhere"'
  run "${CHECK}"
  assert_failure 1
  assert_output --partial 'run-all-checks'
}

@test "fails on a second writer in flake.nix" {
  printf '%s\n' '{ shellHook = "git config --local core.hooksPath /tmp/x"; }' > "${FIXTURE_FLAKE}"
  run "${CHECK}"
  assert_failure 1
  assert_output --partial 'second writer of the hook path'
}

@test "names the offending line number" {
  write_script "${FIXTURE_CI}/rogue" 'echo one' 'git config core.hooksPath "/tmp/elsewhere"'
  run "${CHECK}"
  assert_failure 1
  assert_output --partial 'rogue:3'
}

@test "ignores a commented-out setting" {
  write_script "${FIXTURE_CI}/commented" '# git config --local core.hooksPath "/tmp/elsewhere"'
  run "${CHECK}"
  assert_success
}

@test "ignores a --get read" {
  write_script "${FIXTURE_CI}/reader" 'git config --local --get core.hooksPath "unused"'
  run "${CHECK}"
  assert_success
}

@test "ignores an --unset-all" {
  write_script "${FIXTURE_CI}/unsetter" 'git config --local --unset-all core.hooksPath "unused"'
  run "${CHECK}"
  assert_success
}

@test "ignores the transient -c in-process override" {
  write_script "${FIXTURE_CI}/transient" 'git -c core.hooksPath=/dev/null config --list'
  run "${CHECK}"
  assert_success
}

@test "ignores a bare read with no value token" {
  write_script "${FIXTURE_CI}/bare" 'current="$(git config core.hooksPath)"'
  run "${CHECK}"
  assert_success
}

@test "ignores prose naming the key outside a config invocation" {
  write_script "${FIXTURE_CI}/prose" 'printf "core.hooksPath is unset\n"'
  run "${CHECK}"
  assert_success
}

@test "fails when flake.nix declares a pre-commit-hooks input" {
  printf '%s\n' '{ inputs.pre-commit-hooks.url = "github:example/thing"; }' > "${FIXTURE_FLAKE}"
  run "${CHECK}"
  assert_failure 1
  assert_output --partial 'hook-module flake input declared'
}

@test "fails when flake.nix names the git-hooks.nix flake" {
  printf '%s\n' '{ inputs.hooks.url = "github:cachix/git-hooks.nix"; }' > "${FIXTURE_FLAKE}"
  run "${CHECK}"
  assert_failure 1
  assert_output --partial 'hook-module flake input declared'
}

@test "explains why a hook-module input is refused" {
  printf '%s\n' '{ inputs.pre-commit-hooks.url = "github:example/thing"; }' > "${FIXTURE_FLAKE}"
  run "${CHECK}"
  assert_failure 1
  assert_output --partial 'rewrites the hook path on every devShell entry'
  assert_output --partial 'deciding which'
}

@test "ignores a commented-out hook-module input" {
  printf '%s\n' '# inputs.pre-commit-hooks.url = "github:example/thing";' > "${FIXTURE_FLAKE}"
  run "${CHECK}"
  assert_success
}

@test "passes when there is no flake file at all" {
  rm "${FIXTURE_FLAKE}"
  run "${CHECK}"
  assert_success
}

@test "fails when the sanctioned writer sets nothing" {
  write_script "${SANCTIONED}" 'echo "activation moved elsewhere"'
  run "${CHECK}"
  assert_failure 1
  assert_output --partial 'stale SANCTIONED_WRITER'
}

@test "fails on an EXEMPT entry naming no file" {
  export EXEMPT_OVERRIDE='.ci/gone'
  run "${CHECK}"
  assert_failure 1
  assert_output --partial 'stale EXEMPT entry'
  assert_output --partial '.ci/gone'
}

@test "fails on an EXEMPT entry naming a file that sets nothing" {
  write_script "${FIXTURE_CI}/quiet" 'echo hi'
  export EXEMPT_OVERRIDE="${FIXTURE_CI}/quiet"
  run "${CHECK}"
  assert_failure 1
  assert_output --partial 'stale EXEMPT entry'
}

@test "an EXEMPT entry suppresses a real second writer" {
  write_script "${FIXTURE_CI}/rogue" 'git config core.hooksPath "/tmp/elsewhere"'
  export EXEMPT_OVERRIDE="${FIXTURE_CI}/rogue"
  run "${CHECK}"
  assert_success
}

@test "passes on an otherwise empty scope" {
  rm "${FIXTURE_FLAKE}"
  run "${CHECK}"
  assert_success
}

@test "dies when given an argument" {
  run --separate-stderr "${CHECK}" 'unexpected'
  assert_failure
  assert_stderr --partial 'Expected no arguments'
}
