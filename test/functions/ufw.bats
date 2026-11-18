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

@test "rule_exists: succeeds when ufw reports an existing rule on insert" {
  export UFW_OUTPUT=$'Skipping inserting existing rule\nSkipping inserting existing rule (v6)'
  run ufw::rule_exists insert 1 allow ssh
  assert_success
}

@test "rule_exists: fails when an insert would update one family" {
  export UFW_OUTPUT=$'Skipping inserting existing rule\nRules updated (v6)'
  run ufw::rule_exists insert 1 allow ssh
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

# Writes ufw config fixtures and redirects `source` of the real paths to them.
# $1 = /etc/ufw/ufw.conf contents, $2 = /etc/default/ufw contents
install_config_fixtures() {
  printf '%s\n' "$1" > "${BATS_TEST_TMPDIR}/ufw.conf"
  printf '%s\n' "$2" > "${BATS_TEST_TMPDIR}/default-ufw"
  # shellcheck disable=SC2329 # invoked indirectly when the helpers call `source`
  source() {
    case "$1" in
      '/etc/ufw/ufw.conf') builtin source "${BATS_TEST_TMPDIR}/ufw.conf" ;;
      '/etc/default/ufw') builtin source "${BATS_TEST_TMPDIR}/default-ufw" ;;
      *) builtin source "$@" ;;
    esac
  }
}

# Writes an /etc/default/ufw fixture with one policy variable set.
# $1 = variable name, $2 = value
install_policy_fixture() {
  install_config_fixtures 'ENABLED=no' "$1=\"$2\""
}

# ---------- is_enabled ----------

@test "is_enabled: succeeds when ENABLED=yes" {
  install_config_fixtures 'ENABLED=yes' ''
  run ufw::is_enabled
  assert_success
}

@test "is_enabled: fails when ENABLED=no" {
  install_config_fixtures 'ENABLED=no' ''
  run ufw::is_enabled
  assert_failure 1
}

@test "is_enabled: fails when ENABLED is unset" {
  install_config_fixtures '' ''
  run ufw::is_enabled
  assert_failure 1
}

@test "is_enabled: extra arg fails with arity message" {
  run ufw::is_enabled extra
  assert_failure 1
  assert_output --partial 'Expected no arguments'
}

# ---------- status ----------

@test "status: prints active when ufw reports Status: active" {
  export UFW_OUTPUT=$'Status: active\n\nTo                         Action      From'
  run ufw::status
  assert_success
  assert_output 'active'
}

@test "status: prints inactive when ufw reports Status: inactive" {
  export UFW_OUTPUT='Status: inactive'
  run ufw::status
  assert_success
  assert_output 'inactive'
}

@test "status: runs ufw status under LC_ALL=C" {
  export UFW_OUTPUT='Status: active'
  run ufw::status
  assert_success
  run cli_shim::calls ufw
  assert_output 'status LC_ALL=C'
}

@test "status: dies on unrecognized ufw output" {
  export UFW_OUTPUT='Something else'
  run ufw::status
  assert_failure 1
  assert_output --partial 'Something else'
}

@test "status: dies with ufw output when ufw fails" {
  export UFW_OUTPUT='ERROR: You need to be root to run this script'
  export UFW_EXIT=1
  run ufw::status
  assert_failure 1
  assert_output --partial 'You need to be root'
}

@test "status: extra arg fails with arity message" {
  run ufw::status extra
  assert_failure 1
  assert_output --partial 'Expected no arguments'
}

# ---------- default_policy ----------

@test "default_policy: maps incoming DROP to deny" {
  install_policy_fixture DEFAULT_INPUT_POLICY DROP
  run ufw::default_policy incoming
  assert_success
  assert_output 'deny'
}

@test "default_policy: maps incoming REJECT to reject" {
  install_policy_fixture DEFAULT_INPUT_POLICY REJECT
  run ufw::default_policy incoming
  assert_success
  assert_output 'reject'
}

@test "default_policy: maps incoming ACCEPT to allow" {
  install_policy_fixture DEFAULT_INPUT_POLICY ACCEPT
  run ufw::default_policy incoming
  assert_success
  assert_output 'allow'
}

@test "default_policy: maps outgoing DROP to deny" {
  install_policy_fixture DEFAULT_OUTPUT_POLICY DROP
  run ufw::default_policy outgoing
  assert_success
  assert_output 'deny'
}

@test "default_policy: maps outgoing REJECT to reject" {
  install_policy_fixture DEFAULT_OUTPUT_POLICY REJECT
  run ufw::default_policy outgoing
  assert_success
  assert_output 'reject'
}

@test "default_policy: maps outgoing ACCEPT to allow" {
  install_policy_fixture DEFAULT_OUTPUT_POLICY ACCEPT
  run ufw::default_policy outgoing
  assert_success
  assert_output 'allow'
}

@test "default_policy: maps routed DROP to deny" {
  install_policy_fixture DEFAULT_FORWARD_POLICY DROP
  run ufw::default_policy routed
  assert_success
  assert_output 'deny'
}

@test "default_policy: maps routed REJECT to reject" {
  install_policy_fixture DEFAULT_FORWARD_POLICY REJECT
  run ufw::default_policy routed
  assert_success
  assert_output 'reject'
}

@test "default_policy: maps routed ACCEPT to allow" {
  install_policy_fixture DEFAULT_FORWARD_POLICY ACCEPT
  run ufw::default_policy routed
  assert_success
  assert_output 'allow'
}

@test "default_policy: reads only the variable for the given direction" {
  install_config_fixtures 'ENABLED=no' $'DEFAULT_INPUT_POLICY="DROP"\nDEFAULT_OUTPUT_POLICY="ACCEPT"'
  run ufw::default_policy outgoing
  assert_success
  assert_output 'allow'
}

@test "default_policy: dies on an unknown direction" {
  install_policy_fixture DEFAULT_INPUT_POLICY DROP
  run ufw::default_policy sideways
  assert_failure 1
  assert_output --partial 'sideways'
}

@test "default_policy: dies on an unrecognized policy value" {
  install_policy_fixture DEFAULT_INPUT_POLICY BOGUS
  run ufw::default_policy incoming
  assert_failure 1
  assert_output --partial 'BOGUS'
}

@test "default_policy: dies when the policy variable is unset" {
  install_config_fixtures 'ENABLED=no' ''
  run ufw::default_policy incoming
  assert_failure 1
  assert_output --partial 'DEFAULT_INPUT_POLICY'
}

@test "default_policy: no args fails with arity message" {
  run ufw::default_policy
  assert_failure 1
  assert_output --partial 'Expected exactly 1 argument'
}

@test "default_policy: two args fails with arity message" {
  run ufw::default_policy incoming outgoing
  assert_failure 1
  assert_output --partial 'Expected exactly 1 argument'
}
