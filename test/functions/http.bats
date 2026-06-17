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
  source "${SCRIPTS_DIR}/functions/http.bash"
}

# ---------- curl ----------

@test "curl: passes wrapper flag set + url" {
  cli_shim::record curl
  run http::curl 'https://example.com'
  assert_success
  run cli_shim::calls curl
  assert_output '--disable --fail --silent --location --show-error https://example.com'
}

@test "curl: forwards extra user args after wrapper flags" {
  cli_shim::record curl
  run http::curl --output '/tmp/out' 'https://example.com'
  assert_success
  run cli_shim::calls curl
  assert_output '--disable --fail --silent --location --show-error --output /tmp/out https://example.com'
}

@test "curl: accepts zero args (pass-through)" {
  cli_shim::record curl
  run http::curl
  assert_success
  run cli_shim::calls curl
  assert_output '--disable --fail --silent --location --show-error'
}

# ---------- wget ----------

@test "wget: passes --no-config + url" {
  cli_shim::record wget
  run http::wget 'https://example.com'
  assert_success
  run cli_shim::calls wget
  assert_output '--no-config https://example.com'
}

@test "wget: forwards extra user args" {
  cli_shim::record wget
  run http::wget --output-document '/tmp/out' 'https://example.com'
  assert_success
  run cli_shim::calls wget
  assert_output '--no-config --output-document /tmp/out https://example.com'
}

@test "wget: accepts zero args" {
  cli_shim::record wget
  run http::wget
  assert_success
  run cli_shim::calls wget
  assert_output '--no-config'
}

# ---------- url_reachable ----------

@test "url_reachable: returns success when curl succeeds" {
  cli_shim::record_with_output curl '' 0
  run http::url_reachable 'https://example.com'
  assert_success
}

@test "url_reachable: returns failure when curl fails" {
  cli_shim::record_with_output curl '' 1
  run http::url_reachable 'https://example.com'
  assert_failure
}

@test "url_reachable: passes --output /dev/null and --head to curl" {
  cli_shim::record curl
  run http::url_reachable 'https://example.com'
  assert_success
  run cli_shim::calls curl
  assert_output '--disable --fail --silent --location --show-error --output /dev/null --head https://example.com'
}

@test "url_reachable: fails with zero args" {
  run http::url_reachable
  assert_failure
}

@test "url_reachable: fails with two args" {
  run http::url_reachable 'https://example.com' 'https://other.com'
  assert_failure
}
