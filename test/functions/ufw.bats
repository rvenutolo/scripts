# shellcheck disable=SC2030,SC2031 # BATS isolates each @test in its own subshell

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  # shellcheck disable=SC1091
  source "${REPO_DIR}/test/test_helper/cli_shim.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/ufw.bash"
  cli_shim::install_passthrough_sudo
  install_ufw_shim
}

# ufw shim: records "$*" and the LC_ALL it saw to ufw.calls, prints ${UFW_OUTPUT}, exits ${UFW_EXIT:-0}.
install_ufw_shim() {
  path_shim::add ufw "$(
    cat << 'EOF'
#!/usr/bin/env bash
printf '%s LC_ALL=%s\n' "$*" "${LC_ALL:-}" >> "${BATS_TEST_TMPDIR}/ufw.calls"
printf '%s\n' "${UFW_OUTPUT:-}"
exit "${UFW_EXIT:-0}"
EOF
  )"
}

# Calls rule_exists the way scripts do, as an `if` condition, where errexit does not apply.
rule_exists_in_if() {
  if ufw::rule_exists "$@"; then
    printf 'EXISTS\n'
  else
    printf 'MISSING\n'
  fi
}

# ---------- rule_exists ----------

@test "rule_exists: succeeds when ufw reports the rule as existing" {
  export UFW_OUTPUT=$'Skipping adding existing rule\nSkipping adding existing rule (v6)'
  run ufw::rule_exists allow ssh
  assert_success
}

@test "rule_exists: fails when ufw would add the rule" {
  export UFW_OUTPUT=$'Rules updated\nRules updated (v6)'
  run ufw::rule_exists allow ssh
  assert_failure 1
}

@test "rule_exists: fails when only one address family exists" {
  export UFW_OUTPUT=$'Skipping adding existing rule\nRules updated (v6)'
  run ufw::rule_exists allow ssh
  assert_failure 1
}

@test "rule_exists: fails when ufw output is empty" {
  export UFW_OUTPUT=''
  run ufw::rule_exists allow ssh
  assert_failure 1
}

@test "rule_exists: passes --dry-run, LC_ALL=C and the rule args through" {
  export UFW_OUTPUT='Skipping adding existing rule'
  run ufw::rule_exists allow proto udp from 10.0.0.0/8 to 10.0.0.1 port 53
  assert_success
  run cli_shim::calls ufw
  assert_output '--dry-run allow proto udp from 10.0.0.0/8 to 10.0.0.1 port 53 LC_ALL=C'
}

@test "rule_exists: dies with ufw output when the dry-run fails" {
  export UFW_OUTPUT='ERROR: Bad port'
  export UFW_EXIT=1
  run rule_exists_in_if allow 99999
  assert_failure 1
  assert_output --partial 'ERROR: Bad port'
  refute_output --partial 'EXISTS'
  refute_output --partial 'MISSING'
}

@test "rule_exists: no args fails with arity message" {
  run ufw::rule_exists
  assert_failure 1
  assert_output --partial 'Expected at least 1 argument'
}

# ---------- add_rule ----------

@test "add_rule: runs ufw with the given args" {
  run ufw::add_rule allow in on tailscale0
  assert_success
  run cli_shim::calls ufw
  assert_output --regexp '^allow in on tailscale0 LC_ALL='
}

@test "add_rule: propagates ufw failure" {
  export UFW_EXIT=1
  run ufw::add_rule allow in on tailscale0
  assert_failure 1
}

@test "add_rule: no args fails with arity message" {
  run ufw::add_rule
  assert_failure 1
  assert_output --partial 'Expected at least 1 argument'
}
