#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  # shellcheck disable=SC1091
  source "${REPO_DIR}/test/test_helper/cli_shim.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/strings.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/ip.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/network.bash"
}

# ---------- local_ip ----------

@test "local_ip: parses src field from canned ip output" {
  cli_shim::record_with_output ip '8.8.8.8 via 192.168.1.1 dev wlp3s0 src 192.168.1.42 uid 1000'
  run network::local_ip
  assert_success
  assert_output '192.168.1.42'
}

@test "local_ip: handles IP at end of line" {
  cli_shim::record_with_output ip '8.8.8.8 dev eth0 src 10.0.0.5'
  run network::local_ip
  assert_success
  assert_output '10.0.0.5'
}

@test "local_ip: dies with args" {
  run network::local_ip 'extra'
  assert_failure
  assert_output --partial 'Expected no arguments'
}

# ---------- local_network ----------

@test "local_network: returns 10.0.0.0/8 for 10.x address" {
  cli_shim::record_with_output ip '8.8.8.8 dev eth0 src 10.5.5.5'
  run network::local_network
  assert_success
  assert_output '10.0.0.0/8'
}

@test "local_network: returns 172.16.0.0/12 for 172.20.x address" {
  cli_shim::record_with_output ip '8.8.8.8 dev eth0 src 172.20.0.1'
  run network::local_network
  assert_success
  assert_output '172.16.0.0/12'
}

@test "local_network: returns 192.168.0.0/16 for 192.168.x address" {
  cli_shim::record_with_output ip '8.8.8.8 dev eth0 src 192.168.7.42'
  run network::local_network
  assert_success
  assert_output '192.168.0.0/16'
}

@test "local_network: dies for non-RFC1918 address" {
  cli_shim::record_with_output ip '8.8.8.8 dev eth0 src 8.8.4.4'
  run network::local_network
  assert_failure
  assert_output --partial 'Could not determine local network IPv4 range'
}

@test "local_network: dies with args" {
  run network::local_network 'extra'
  assert_failure
  assert_output --partial 'Expected no arguments'
}
