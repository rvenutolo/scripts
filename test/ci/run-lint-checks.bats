setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  AGG="${REPO_DIR}/.ci/run-lint-checks"
}

# .ci/run-lint-checks (an aggregator) derives its own repo root via
# `git rev-parse --show-toplevel`, as do the sub-checks it shells out to.
# common.bash's #248 hardening leaves CWD at BATS_TEST_TMPDIR (outside any git
# repo) by design, so cd into REPO_DIR before every invocation — this test
# targets the real repo.
run_check() {
  cd "${REPO_DIR}" || return 1
  run "$@"
}

@test "runs clean against the real repo" {
  run_check "${AGG}"
  assert_success
}

@test "dies when given an argument" {
  run_check "${AGG}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "a gitignored directory holding invalid YAML does not fail the run" {
  # The #253 regression test. `yamllint .` walked the working tree and did not
  # skip gitignored paths, so an agent worktree or any scratch YAML failed the
  # local gate while CI — which checks out clean — stayed green.
  local probe="${REPO_DIR}/docs/superpowers/_yamllint_probe"
  mkdir --parents "${probe}"
  printf 'a:\n   b:   {  x }\n' > "${probe}/bad.yaml"
  # Guard the premise: if this path ever stops being gitignored the test would
  # silently stop testing anything, and would dirty the real repo besides.
  run git -C "${REPO_DIR}" check-ignore --quiet "${probe}/bad.yaml"
  assert_success
  run_check "${AGG}"
  local rc="${status}"
  rm --recursive --force "${probe}"
  [[ "${rc}" -eq 0 ]]
}

@test "yamllint is handed the tracked file set, not the working tree" {
  # The other half of #253: scoping yamllint must not declaw it. Record what
  # the aggregator actually passes. Pre-fix this was the single argument `.`;
  # post-fix it is the tracked YAML paths, so a real violation in a tracked
  # file is still linted.
  path_shim::add yamllint "#!/usr/bin/env bash
printf '%s\n' \"\$@\" > '${BATS_TEST_TMPDIR}/yamllint-args'
exit 0"
  run_check "${AGG}"
  assert_success
  run cat "${BATS_TEST_TMPDIR}/yamllint-args"
  assert_success
  refute_line '.'
  assert_line '.github/workflows/ci.yml'
  assert_line '.yamllint.yml'
}

@test "fails (exit 1) when a sub-lint fails but still runs the rest" {
  # Stub actionlint (first lint) to fail; aggregator must aggregate, not abort.
  path_shim::add actionlint 'echo "stub actionlint fail" >&2; exit 1'
  run_check "${AGG}"
  assert_failure
  assert_output --partial 'one or more lint checks failed'
}
