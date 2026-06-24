setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-script-has-test"
  CI="${BATS_TEST_TMPDIR}/ci"
  TEST_CI="${BATS_TEST_TMPDIR}/test_ci"
  mkdir -p "${CI}" "${TEST_CI}"
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

run_check() {
  CI_DIR_OVERRIDE="${CI}" TEST_CI_DIR_OVERRIDE="${TEST_CI}" run "${CHECK}" "$@"
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
}

@test "passes when an exempt script has no test" {
  make_ci_script 'check-foo'
  make_test 'check-foo'
  make_ci_script 'apply-repo-settings'
  run_check
  assert_success
}

@test "dies when given an argument" {
  run_check oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}
