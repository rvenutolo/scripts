#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  if ! command -v pwgen > /dev/null 2>&1; then
    skip 'pwgen not installed'
  fi
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/passwords.bash"
}

# ---------- passwords::generate ----------

@test "generate: default length 64" {
  run passwords::generate
  assert_success
  [[ "${#output}" -eq 64 ]]
}

@test "generate: explicit length 16" {
  run passwords::generate 16
  assert_success
  [[ "${#output}" -eq 16 ]]
}

@test "generate: explicit length 32" {
  run passwords::generate 32
  assert_success
  [[ "${#output}" -eq 32 ]]
}

@test "generate: alphanumeric only (no symbols)" {
  run passwords::generate 64
  assert_success
  [[ "${output}" =~ ^[A-Za-z0-9]+$ ]]
}

@test "generate: two consecutive calls produce different output" {
  local a
  a="$(passwords::generate 32)"
  local b
  b="$(passwords::generate 32)"
  [[ "${a}" != "${b}" ]]
}

@test "generate: dies with 2 args" {
  run passwords::generate 16 'extra'
  assert_failure
  assert_output --partial 'Expected at most 1 argument'
}

# ---------- passwords::generate_with_symbols ----------

@test "generate_with_symbols: default length 64" {
  run passwords::generate_with_symbols
  assert_success
  [[ "${#output}" -eq 64 ]]
}

@test "generate_with_symbols: explicit length 32" {
  run passwords::generate_with_symbols 32
  assert_success
  [[ "${#output}" -eq 32 ]]
}

@test "generate_with_symbols: excludes the disallowed character set" {
  # --remove-chars excludes: !&*{}[],#>|@`"%-.$\/:;='
  # Output must NOT contain any of these.
  run passwords::generate_with_symbols 64
  assert_success
  [[ ! "${output}" =~ [\!\&\*\{\}\[\],\#\>\|\@\`\"\%\.\$\\/\:\;\=\'-] ]]
}

@test "generate_with_symbols: two consecutive calls differ" {
  local a
  a="$(passwords::generate_with_symbols 32)"
  local b
  b="$(passwords::generate_with_symbols 32)"
  [[ "${a}" != "${b}" ]]
}

@test "generate_with_symbols: dies with 2 args" {
  run passwords::generate_with_symbols 16 'extra'
  assert_failure
  assert_output --partial 'Expected at most 1 argument'
}
