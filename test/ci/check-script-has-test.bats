setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-script-has-test"
  CI="${BATS_TEST_TMPDIR}/ci"
  TEST_CI="${BATS_TEST_TMPDIR}/test_ci"
  ROOT="${BATS_TEST_TMPDIR}/root"
  TEST_ROOT="${BATS_TEST_TMPDIR}/test_root"
  HOOKS="${BATS_TEST_TMPDIR}/githooks"
  SHIMS="${BATS_TEST_TMPDIR}/shims"
  TEST_SHIMS="${BATS_TEST_TMPDIR}/test_shims"
  mkdir -p "${CI}" "${TEST_CI}" "${ROOT}" "${TEST_ROOT}" "${HOOKS}" "${SHIMS}" "${TEST_SHIMS}"
  # Both shipped lists are empty today, but an entry added later would name a
  # script in the real repo that does not exist in the synthetic fixture dirs
  # below, and would read as stale. Set-but-empty clears them regardless; tests
  # that need an exemption re-set it on the command itself, and the two tests
  # that pin the shipped defaults unset it.
  export EXEMPT_OVERRIDE=''
  export ROOT_EXEMPT_OVERRIDE=''
  export HOOKS_EXEMPT_OVERRIDE=''
  export SHIMS_EXEMPT_OVERRIDE=''
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

# Drop an executable, shebang-bearing fixture into the fake .githooks dir. The
# hooks scope pairs into test/ci/, so its paired fixture is make_test.
make_hook() {
  local -r name="$1"
  printf '#!/usr/bin/env bash\ntrue\n' > "${HOOKS}/${name}"
  chmod +x "${HOOKS}/${name}"
}

make_root_test() {
  local -r name="$1"
  printf '@test "x" { true; }\n' > "${TEST_ROOT}/${name}.bats"
}

# Drop an executable, shebang-bearing fixture into a subdir of the fake
# scripts/shims dir; the scope is recursive, like .ci/.
make_shim() {
  local -r name="$1"
  mkdir --parents "${SHIMS}/claude"
  printf '#!/usr/bin/env bash\ntrue\n' > "${SHIMS}/claude/${name}"
  chmod +x "${SHIMS}/claude/${name}"
}

make_shim_test() {
  local -r name="$1"
  printf '@test "x" { true; }\n' > "${TEST_SHIMS}/${name}.bats"
}

# All three scopes are always pinned at fixture dirs. Without the seams a scope
# would fall back to the live checkout, and every test here would silently depend
# on real repo state.
# .ci/check-script-has-test derives its own repo root via `git rev-parse
# --show-toplevel`. common.bash's fixture-escape hardening leaves CWD at
# BATS_TEST_TMPDIR (outside any git repo) by design, so cd into REPO_DIR before
# every invocation.
run_check() {
  cd "${REPO_DIR}" || return 1
  CI_DIR_OVERRIDE="${CI}" TEST_CI_DIR_OVERRIDE="${TEST_CI}" \
    ROOT_DIR_OVERRIDE="${ROOT}" TEST_ROOT_DIR_OVERRIDE="${TEST_ROOT}" \
    HOOKS_DIR_OVERRIDE="${HOOKS}" \
    SHIMS_DIR_OVERRIDE="${SHIMS}" TEST_SHIMS_DIR_OVERRIDE="${TEST_SHIMS}" \
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

@test "the shipped .ci exemption list is empty" {
  # apply-repo-settings was the last entry, exempted on the grounds that a script
  # which mutates the live repo via gh has nothing deterministic to assert. It
  # now has test/ci/apply-repo-settings.bats (gh shimmed via cli_shim), so the
  # entry went with it and no .ci script is exempt any more.
  unset EXEMPT_OVERRIDE
  make_ci_script 'apply-repo-settings'
  run_check
  assert_failure
  assert_output --partial 'test/ci/apply-repo-settings.bats'
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

@test "every scope is reported in a single run" {
  make_ci_script 'check-orphan'
  make_root_script 'run-orphan'
  make_hook 'hook-orphan'
  run_check
  assert_failure
  assert_output --partial 'test/ci/check-orphan.bats'
  assert_output --partial 'test/root/run-orphan.bats'
  assert_output --partial 'test/ci/hook-orphan.bats'
}

@test "passes when every tracked git hook has a paired test" {
  make_hook 'commit-msg'
  make_test 'commit-msg'
  make_hook 'pre-push'
  make_test 'pre-push'
  run_check
  assert_success
}

@test "fails when a tracked git hook has no paired test" {
  make_hook 'pre-commit'
  run_check
  assert_failure
  assert_output --partial 'pre-commit: no paired test/ci/pre-commit.bats'
}

@test "a non-executable file in the hooks dir is not held to the mandate" {
  printf '#!/usr/bin/env bash\ntrue\n' > "${HOOKS}/not-a-hook"
  run_check
  assert_success
}

@test "an exempt hook is accepted without a paired test" {
  make_hook 'pre-commit'
  HOOKS_EXEMPT_OVERRIDE='pre-commit' run_check
  assert_success
}

@test "a hooks exemption naming no hook is reported stale" {
  HOOKS_EXEMPT_OVERRIDE='hook-ghost' run_check
  assert_failure
  assert_output --partial 'stale EXEMPT entry: hook-ghost matches no script'
}

@test "a hooks exemption whose hook does have a test is reported stale" {
  make_hook 'pre-commit'
  make_test 'pre-commit'
  HOOKS_EXEMPT_OVERRIDE='pre-commit' run_check
  assert_failure
  assert_output --partial 'stale EXEMPT entry: pre-commit already has a paired'
}

@test "the shipped HOOKS_EXEMPT list is empty" {
  unset HOOKS_EXEMPT_OVERRIDE
  make_hook 'commit-msg'
  make_test 'commit-msg'
  run_check
  assert_success
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

@test "passes when every shim has a paired test" {
  make_shim 'pkill'
  make_shim_test 'pkill'
  run_check
  assert_success
}

@test "fails when a shim has no paired test" {
  make_shim 'killall'
  run_check
  assert_failure
  assert_output --partial 'killall: no paired test/shims/killall.bats'
}

@test "a non-executable library under the shims dir is not held to the mandate" {
  mkdir --parents "${SHIMS}/claude"
  printf '#!/usr/bin/env bash\ntrue\n' > "${SHIMS}/claude/lib.bash"
  run_check
  assert_success
}

@test "an exempt shim is accepted without a paired test" {
  make_shim 'killall'
  SHIMS_EXEMPT_OVERRIDE='killall' run_check
  assert_success
}

@test "a shims exemption naming no shim is reported stale" {
  SHIMS_EXEMPT_OVERRIDE='shim-ghost' run_check
  assert_failure
  assert_output --partial 'stale EXEMPT entry: shim-ghost matches no script'
}

@test "the shipped SHIMS_EXEMPT list is empty" {
  unset SHIMS_EXEMPT_OVERRIDE
  make_shim 'pkill'
  make_shim_test 'pkill'
  run_check
  assert_success
}
