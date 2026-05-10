#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/ip.bash"
}

# ---------- ip::ipv4_to_num ----------

@test "ipv4_to_num: 0.0.0.0 -> 0" {
  run ip::ipv4_to_num '0.0.0.0'
  assert_success
  assert_output '0'
}

@test "ipv4_to_num: 255.255.255.255 -> 4294967295" {
  run ip::ipv4_to_num '255.255.255.255'
  assert_success
  assert_output '4294967295'
}

@test "ipv4_to_num: 127.0.0.1 -> 2130706433" {
  run ip::ipv4_to_num '127.0.0.1'
  assert_success
  assert_output '2130706433'
}

@test "ipv4_to_num: 192.168.1.1 -> 3232235777" {
  run ip::ipv4_to_num '192.168.1.1'
  assert_success
  assert_output '3232235777'
}

@test "ipv4_to_num: 10.0.0.1 -> 167772161" {
  run ip::ipv4_to_num '10.0.0.1'
  assert_success
  assert_output '167772161'
}

@test "ipv4_to_num: 1.2.3.4 -> 16909060" {
  run ip::ipv4_to_num '1.2.3.4'
  assert_success
  assert_output '16909060'
}

@test "ipv4_to_num: dies with 0 args" {
  run ip::ipv4_to_num
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "ipv4_to_num: dies with 2 args" {
  run ip::ipv4_to_num '1.2.3.4' 'extra'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- ip::num_to_ipv4 ----------

@test "num_to_ipv4: 0 -> 0.0.0.0" {
  run ip::num_to_ipv4 0
  assert_success
  assert_output '0.0.0.0'
}

@test "num_to_ipv4: 4294967295 -> 255.255.255.255" {
  run ip::num_to_ipv4 4294967295
  assert_success
  assert_output '255.255.255.255'
}

@test "num_to_ipv4: 2130706433 -> 127.0.0.1" {
  run ip::num_to_ipv4 2130706433
  assert_success
  assert_output '127.0.0.1'
}

@test "num_to_ipv4: 3232235777 -> 192.168.1.1" {
  run ip::num_to_ipv4 3232235777
  assert_success
  assert_output '192.168.1.1'
}

@test "num_to_ipv4: 16909060 -> 1.2.3.4" {
  run ip::num_to_ipv4 16909060
  assert_success
  assert_output '1.2.3.4'
}

@test "num_to_ipv4: dies with 0 args" {
  run ip::num_to_ipv4
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "num_to_ipv4: dies with 2 args" {
  run ip::num_to_ipv4 1 2
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- round-trip ----------

@test "round-trip: ipv4 -> num -> ipv4 preserves several addresses" {
  for addr in '0.0.0.0' '127.0.0.1' '192.168.1.1' '10.0.0.1' '255.255.255.255' '8.8.8.8'; do
    local n
    n="$(ip::ipv4_to_num "${addr}")"
    local back
    back="$(ip::num_to_ipv4 "${n}")"
    [[ "${back}" == "${addr}" ]] || {
      printf 'round-trip failed: %s -> %s -> %s\n' "${addr}" "${n}" "${back}" >&2
      return 1
    }
  done
}
