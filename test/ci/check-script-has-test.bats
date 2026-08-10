setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-script-has-test"
  CI="${BATS_TEST_TMPDIR}/ci"
  TEST_CI="${BATS_TEST_TMPDIR}/test_ci"
  ROOT="${BATS_TEST_TMPDIR}/root"
  TEST_ROOT="${BATS_TEST_TMPDIR}/test_root"
  mkdir -p "${CI}" "${TEST_CI}" "${ROOT}" "${TEST_ROOT}"
  # The shipped EXEMPT list names scripts in the real repo, which do not exist in
  # the synthetic fixture dirs below — every entry would read as stale. Set-but-
  # empty clears it; tests that need an exemption re-set it on the command
  # itself, and the two tests that pin the shipped defaults unset it.
  export EXEMPT_OVERRIDE=''
  export ROOT_EXEMPT_OVERRIDE=''
}

# Drop an executable, shebang-bearing fixture script into the fake .ci dir so
# shell_scripts::find (shfmt --find) returns it.
make_ci_script() {
  local -r name="$1"
  printf '#!/usr/bin/env bash\ntrue\n' > "${CI}/${name}"
  chmod +x "${CI}/${name}"
}

make_test() {
  local -r name="$1"
  printf '@test "x" { true; }\n' > "${TEST_CI}/${name}.bats"
}

# Drop an executable, shebang-bearing fixture into the fake repo-root dir.
make_root_script() {
  local -r name="$1"
  printf '#!/usr/bin/env bash\ntrue\n' > "${ROOT}/${name}"
  chmod +x "${ROOT}/${name}"
}

make_root_test() {
  local -r name="$1"
  printf '@test "x" { true; }\n' > "${TEST_ROOT}/${name}.bats"
}

# Both scopes are always pinned at fixture dirs. Without the root seams the
# repo-root scope would fall back to the live checkout, and every test here would
# silently depend on real repo state.
run_check() {
  CI_DIR_OVERRIDE="${CI}" TEST_CI_DIR_OVERRIDE="${TEST_CI}" \
    ROOT_DIR_OVERRIDE="${ROOT}" TEST_ROOT_DIR_OVERRIDE="${TEST_ROOT}" \
    run "${CHECK}" "$@"
}

@test "passes when every .ci script has a paired test" {
  make_ci_script 'check-foo'
  make_test 'check-foo'
  make_ci_script 'check-bar'
  make_test 'check-bar'
  run_check
  assert_success
}

@test "fails and names the script missing its paired test" {
  make_ci_script 'check-foo'
  make_test 'check-foo'
  make_ci_script 'check-orphan'
  run_check
  assert_failure
  assert_output --partial 'check-orphan'
  assert_output --partial 'test/ci/check-orphan.bats'
}

@test "passes when an exempt script has no test" {
  make_ci_script 'check-foo'
  make_test 'check-foo'
  make_ci_script 'apply-repo-settings'
  EXEMPT_OVERRIDE='apply-repo-settings' run_check
  assert_success
}

@test "the shipped .ci exemption list exempts apply-repo-settings" {
  unset EXEMPT_OVERRIDE
  make_ci_script 'apply-repo-settings'
  run_check
  assert_success
}

@test "a .ci exemption naming no script is stale" {
  make_ci_script 'check-foo'
  make_test 'check-foo'
  EXEMPT_OVERRIDE='check-ghost' run_check
  assert_failure
  assert_output --partial 'stale EXEMPT entry: check-ghost'
}

@test "a .ci exemption for a script that has a test is stale" {
  make_ci_script 'check-foo'
  make_test 'check-foo'
  EXEMPT_OVERRIDE='check-foo' run_check
  assert_failure
  assert_output --partial 'stale EXEMPT entry: check-foo'
}

@test "passes when every repo-root runner has a paired test" {
  make_root_script 'run-thing'
  make_root_test 'run-thing'
  run_check
  assert_success
}

@test "fails and names the repo-root runner missing its paired test" {
  make_root_script 'run-orphan'
  run_check
  assert_failure
  assert_output --partial 'run-orphan'
  assert_output --partial 'test/root/run-orphan.bats'
}

@test "ignores non-executable repo-root files" {
  printf '#!/usr/bin/env bash\ntrue\n' > "${ROOT}/flake.nix"
  chmod -x "${ROOT}/flake.nix"
  run_check
  assert_success
}

@test "ignores repo-root directories" {
  mkdir -p "${ROOT}/scripts"
  run_check
  assert_success
}

@test "ignores executable repo-root files that are not shell files" {
  printf 'not a shell script\n' > "${ROOT}/some-binary"
  chmod +x "${ROOT}/some-binary"
  run_check
  assert_success
}

@test "passes with an empty repo root and an empty .ci dir" {
  run_check
  assert_success
}

@test "a root exemption suppresses the missing-test failure" {
  make_root_script 'run-special'
  ROOT_EXEMPT_OVERRIDE='run-special' run_check
  assert_success
}

@test "a root exemption naming no script is stale" {
  make_root_script 'run-thing'
  make_root_test 'run-thing'
  ROOT_EXEMPT_OVERRIDE='run-ghost' run_check
  assert_failure
  assert_output --partial 'stale EXEMPT entry: run-ghost'
}

@test "a root exemption for a script that has a test is stale" {
  make_root_script 'run-thing'
  make_root_test 'run-thing'
  ROOT_EXEMPT_OVERRIDE='run-thing' run_check
  assert_failure
  assert_output --partial 'stale EXEMPT entry: run-thing'
}

@test "the shipped repo-root exemption list is empty" {
  unset ROOT_EXEMPT_OVERRIDE
  make_root_script 'run-orphan'
  run_check
  assert_failure
  assert_output --partial 'test/root/run-orphan.bats'
}

@test "the root scope does not consult the .ci exemption list" {
  # run-orphan is exempt in the .ci scope and satisfies it, but the root scope
  # keeps its own list, so the root copy still needs test/root/run-orphan.bats.
  make_ci_script 'run-orphan'
  make_root_script 'run-orphan'
  EXEMPT_OVERRIDE='run-orphan' run_check
  assert_failure
  assert_output --partial 'test/root/run-orphan.bats'
}

@test "both scopes are reported in a single run" {
  make_ci_script 'check-orphan'
  make_root_script 'run-orphan'
  run_check
  assert_failure
  assert_output --partial 'test/ci/check-orphan.bats'
  assert_output --partial 'test/root/run-orphan.bats'
}

@test "dies when given an argument" {
  run_check oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "--help exits 0" {
  run_check --help
  assert_success
}
