#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/test/test_helper/cli_shim.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/wrappers.bash"
}

# ---------- curl ----------

@test "curl: passes wrapper flag set + url" {
  cli_shim::record curl
  run wrappers::curl 'https://example.com'
  assert_success
  run cli_shim::calls curl
  assert_output '--disable --fail --silent --location --show-error https://example.com'
}

@test "curl: forwards extra user args after wrapper flags" {
  cli_shim::record curl
  run wrappers::curl --output '/tmp/out' 'https://example.com'
  assert_success
  run cli_shim::calls curl
  assert_output '--disable --fail --silent --location --show-error --output /tmp/out https://example.com'
}

@test "curl: accepts zero args (pass-through)" {
  cli_shim::record curl
  run wrappers::curl
  assert_success
  run cli_shim::calls curl
  assert_output '--disable --fail --silent --location --show-error'
}

# ---------- wget ----------

@test "wget: passes --no-config + url" {
  cli_shim::record wget
  run wrappers::wget 'https://example.com'
  assert_success
  run cli_shim::calls wget
  assert_output '--no-config https://example.com'
}

@test "wget: forwards extra user args" {
  cli_shim::record wget
  run wrappers::wget --output-document '/tmp/out' 'https://example.com'
  assert_success
  run cli_shim::calls wget
  assert_output '--no-config --output-document /tmp/out https://example.com'
}

@test "wget: accepts zero args" {
  cli_shim::record wget
  run wrappers::wget
  assert_success
  run cli_shim::calls wget
  assert_output '--no-config'
}
