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

# ---------- retry::until_success ----------

@test "until_success: succeeds first try — command called once" {
  SUCCEED_ON_CALL=1 run retry::until_success flaky_cmd
  assert_success
  assert_equal "$(cat "${BATS_TEST_TMPDIR}/flaky_count")" '1'
}

@test "until_success: succeeds on third try — command called 3x, no sleep invoked" {
  SUCCEED_ON_CALL=3 run retry::until_success flaky_cmd
  assert_success
  assert_equal "$(cat "${BATS_TEST_TMPDIR}/flaky_count")" '3'
  [[ ! -f "${BATS_TEST_TMPDIR}/sleep_log" ]]
}

@test "until_success: no args triggers arity guard" {
  run retry::until_success
  assert_failure
}

# ---------- retry::until_deadline ----------

@test "until_deadline: succeeds immediately when cmd is true — returns 0 fast, no sleep" {
  run retry::until_deadline 10 1 true
  assert_success
  [[ ! -f "${BATS_TEST_TMPDIR}/sleep_log" ]]
}

@test "until_deadline: succeeds after two failing attempts within the deadline" {
  # Real sleep so the SECONDS-based deadline advances; flaky_cmd succeeds on the 3rd call.
  path_shim::add sleep "#!/usr/bin/env bash
exec /usr/bin/sleep \"\$1\""
  SUCCEED_ON_CALL=3 run retry::until_deadline 10 1 flaky_cmd
  assert_success
  assert_equal "$(cat "${BATS_TEST_TMPDIR}/flaky_count")" '3'
}

@test "until_deadline: times out and dies when cmd never succeeds" {
  # Real sleep so the SECONDS-based deadline actually elapses.
  path_shim::add sleep "#!/usr/bin/env bash
exec /usr/bin/sleep \"\$1\""
  run --separate-stderr retry::until_deadline 1 1 false
  assert_failure
  [[ "${stderr}" == *'Timed out after 1s waiting for'* ]]
}

@test "until_deadline: no args triggers arity guard" {
  run retry::until_deadline
  assert_failure
}

@test "until_deadline: one arg triggers arity guard" {
  run retry::until_deadline 10
  assert_failure
}

@test "until_deadline: two args triggers arity guard" {
  run retry::until_deadline 10 1
  assert_failure
}
