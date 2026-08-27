setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  CHECK="${REPO_DIR}/.ci/check-jsonschema"
}

# .ci/check-jsonschema derives its own repo root via `git rev-parse
# --show-toplevel`. common.bash's fixture-escape hardening leaves CWD at
# BATS_TEST_TMPDIR (outside any git repo) by design, so cd into REPO_DIR before
# every invocation — this test targets the real repo.
run_check() {
  cd "${REPO_DIR}" || return 1
  # SAFE_BASH_ENV, not '': clearing BASH_ENV outright would also strip kcov's trace
  # helper, and this script then reads 0% with its whole suite behind it. See
  # test_helper/common.bash for why the kcov value is safe to keep.
  BASH_ENV="${SAFE_BASH_ENV}" run "$@"
}

@test "passes when shimmed check-jsonschema exits 0 for all targets" {
  path_shim::add 'check-jsonschema' '#!/usr/bin/env bash
printf "%s\n" "$*" >> "'"${BATS_TEST_TMPDIR}"'/calls.log"
exit 0'
  run_check "${CHECK}"
  assert_success
  run wc -l < "${BATS_TEST_TMPDIR}/calls.log"
  [ "${output}" -ge 3 ]
}

@test "fails when shimmed check-jsonschema exits non-zero" {
  path_shim::add 'check-jsonschema' '#!/usr/bin/env bash
exit 1'
  run_check "${CHECK}"
  assert_failure
  assert_output --partial 'schema validation failed'
}

@test "dies when check-jsonschema is not installed" {
  # run_check neutralizes BASH_ENV, so ~/.bashrc cannot re-export the full
  # nix/sdkman PATH and re-add check-jsonschema behind the restricted PATH set
  # here — the absence the test asserts is real.
  path_shim::mkbin
  PATH="${BATS_TEST_TMPDIR}/bin:/usr/bin:/bin" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'check-jsonschema'
}

@test "dies when given an argument" {
  path_shim::add 'check-jsonschema' '#!/usr/bin/env bash
exit 0'
  run_check "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}
