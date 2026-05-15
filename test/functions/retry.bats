#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # log.bash already sourced by common
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/retry.bash"

  # No-op sleep shim so tests run instantly; log args for duration assertions
  path_shim::add sleep "echo \"\$1\" >> \"${BATS_TEST_TMPDIR}/sleep_log\""

  # Stub that succeeds on the Nth call (controlled by SUCCEED_ON_CALL env var).
  # Uses a counter file under BATS_TEST_TMPDIR so it survives across subshell calls.
  path_shim::add flaky_cmd "
count_file=\"${BATS_TEST_TMPDIR}/flaky_count\"
current=\$(cat \"\${count_file}\" 2>/dev/null || echo 0)
echo \$(( current + 1 )) > \"\${count_file}\"
[[ \$(( current + 1 )) -ge \${SUCCEED_ON_CALL:-1} ]]
"
}

# ---------- retry::with_linear_backoff ----------

@test "with_linear_backoff: succeeds first try — command called once, sleep not called" {
  SUCCEED_ON_CALL=1 run retry::with_linear_backoff 10 5 flaky_cmd
  assert_success
  assert_equal "$(cat "${BATS_TEST_TMPDIR}/flaky_count")" '1'
  [[ ! -f "${BATS_TEST_TMPDIR}/sleep_log" ]]
}

@test "with_linear_backoff: succeeds on third try — command called 3x, sleep called 2x with linear durations" {
  SUCCEED_ON_CALL=3 run retry::with_linear_backoff 10 5 flaky_cmd
  assert_success
  assert_equal "$(cat "${BATS_TEST_TMPDIR}/flaky_count")" '3'
  assert_equal "$(cat "${BATS_TEST_TMPDIR}/sleep_log")" "$(printf '5\n10\n')"
}

@test "with_linear_backoff: fails all attempts — exits non-zero, stderr contains failure message" {
  SUCCEED_ON_CALL=999 run --separate-stderr retry::with_linear_backoff 3 5 flaky_cmd
  assert_failure
  assert_equal "$(cat "${BATS_TEST_TMPDIR}/flaky_count")" '3'
  [[ "${stderr}" == *'Failed after 3 tries'* ]]
}

@test "with_linear_backoff: too few args triggers arity guard" {
  run retry::with_linear_backoff 3 5
  assert_failure
}

# ---------- retry::with_exponential_backoff ----------

@test "with_exponential_backoff: succeeds first try — command called once, sleep not called" {
  SUCCEED_ON_CALL=1 run retry::with_exponential_backoff 10 5 flaky_cmd
  assert_success
  assert_equal "$(cat "${BATS_TEST_TMPDIR}/flaky_count")" '1'
  [[ ! -f "${BATS_TEST_TMPDIR}/sleep_log" ]]
}

@test "with_exponential_backoff: succeeds on third try — command called 3x, sleep called 2x with exponential durations" {
  SUCCEED_ON_CALL=3 run retry::with_exponential_backoff 10 5 flaky_cmd
  assert_success
  assert_equal "$(cat "${BATS_TEST_TMPDIR}/flaky_count")" '3'
  # base=5: attempt 1 failed → sleep 5*(2^0)=5, attempt 2 failed → sleep 5*(2^1)=10
  assert_equal "$(cat "${BATS_TEST_TMPDIR}/sleep_log")" "$(printf '5\n10\n')"
}

@test "with_exponential_backoff: fails all attempts — exits non-zero, stderr contains failure message" {
  SUCCEED_ON_CALL=999 run --separate-stderr retry::with_exponential_backoff 3 5 flaky_cmd
  assert_failure
  assert_equal "$(cat "${BATS_TEST_TMPDIR}/flaky_count")" '3'
  [[ "${stderr}" == *'Failed after 3 tries'* ]]
}

@test "with_exponential_backoff: too few args triggers arity guard" {
  run retry::with_exponential_backoff 3 5
  assert_failure
}
