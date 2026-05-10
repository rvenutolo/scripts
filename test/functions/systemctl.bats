#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031 # BATS isolates each @test in its own subshell

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/test/test_helper/cli_shim.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/strings.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/misc.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/prompt.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/systemctl.bash"
  cli_shim::install_passthrough_sudo
}

# Configurable systemctl shim:
#   list-unit-files exits 0 if $UNIT_EXISTS=1, else 1
#   is-enabled exits 0 if $UNIT_ENABLED=1, else 1
#   any other subcommand exits 0
# All invocations recorded to ${BATS_TEST_TMPDIR}/systemctl.calls.
install_systemctl_shim() {
  path_shim::add systemctl "$(
    cat << 'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${BATS_TEST_TMPDIR}/systemctl.calls"
sub=''
for arg in "$@"; do
  case "${arg}" in
    --user | --system | --all | --quiet | --now) ;;
    *) sub="${arg}"; break ;;
  esac
done
case "${sub}" in
  list-unit-files)
    [[ "${UNIT_EXISTS:-0}" == 1 ]] && exit 0 || exit 1
    ;;
  is-enabled)
    [[ "${UNIT_ENABLED:-0}" == 1 ]] && exit 0 || exit 1
    ;;
  *) exit 0 ;;
esac
EOF
  )"
}

# ---------- *_service_unit_file_exists ----------

@test "user_service_unit_file_exists: true when present" {
  install_systemctl_shim
  export UNIT_EXISTS=1
  run systemctl::user_service_unit_file_exists 'foo.service'
  assert_success
}

@test "user_service_unit_file_exists: false when absent" {
  install_systemctl_shim
  export UNIT_EXISTS=0
  run systemctl::user_service_unit_file_exists 'foo.service'
  assert_failure
}

@test "system_service_unit_file_exists: true when present" {
  install_systemctl_shim
  export UNIT_EXISTS=1
  run systemctl::system_service_unit_file_exists 'foo.service'
  assert_success
}

@test "system_service_unit_file_exists: false when absent" {
  install_systemctl_shim
  export UNIT_EXISTS=0
  run systemctl::system_service_unit_file_exists 'foo.service'
  assert_failure
}

# ---------- enable_user_service_unit ----------

@test "enable_user_service_unit: enables when unit exists and not enabled and confirm=y" {
  install_systemctl_shim
  export UNIT_EXISTS=1
  export UNIT_ENABLED=0
  export SCRIPTS_AUTO_ANSWER=y
  run systemctl::enable_user_service_unit 'foo.service'
  assert_success
  run cli_shim::calls systemctl
  assert_output --partial 'enable --now --user --quiet foo.service'
}

@test "enable_user_service_unit: skips when already enabled" {
  install_systemctl_shim
  export UNIT_EXISTS=1
  export UNIT_ENABLED=1
  export SCRIPTS_AUTO_ANSWER=y
  run systemctl::enable_user_service_unit 'foo.service'
  assert_success
  run cli_shim::calls systemctl
  refute_output --partial 'enable --now'
}

@test "enable_user_service_unit: logs when unit absent" {
  install_systemctl_shim
  export UNIT_EXISTS=0
  run systemctl::enable_user_service_unit 'foo.service'
  assert_success
  assert_output --partial 'User service unit files does not exist: foo.service'
}

# ---------- enable_system_service_unit ----------

@test "enable_system_service_unit: enables via sudo when unit exists, not enabled, confirm=y" {
  install_systemctl_shim
  export UNIT_EXISTS=1
  export UNIT_ENABLED=0
  export SCRIPTS_AUTO_ANSWER=y
  run systemctl::enable_system_service_unit 'foo.service'
  assert_success
  run cli_shim::calls systemctl
  assert_output --partial 'enable --now --system --quiet foo.service'
}

# ---------- disable_user_service_unit ----------

@test "disable_user_service_unit: disables when enabled and confirm=y" {
  install_systemctl_shim
  export UNIT_EXISTS=1
  export UNIT_ENABLED=1
  export SCRIPTS_AUTO_ANSWER=y
  run systemctl::disable_user_service_unit 'foo.service'
  assert_success
  run cli_shim::calls systemctl
  assert_output --partial 'disable --now --user --quiet foo.service'
}

@test "disable_user_service_unit: skips when already disabled" {
  install_systemctl_shim
  export UNIT_EXISTS=1
  export UNIT_ENABLED=0
  export SCRIPTS_AUTO_ANSWER=y
  run systemctl::disable_user_service_unit 'foo.service'
  assert_success
  run cli_shim::calls systemctl
  refute_output --partial 'disable --now'
}

# ---------- disable_system_service_unit ----------

@test "disable_system_service_unit: disables via sudo when enabled, confirm=y" {
  install_systemctl_shim
  export UNIT_EXISTS=1
  export UNIT_ENABLED=1
  export SCRIPTS_AUTO_ANSWER=y
  run systemctl::disable_system_service_unit 'foo.service'
  assert_success
  run cli_shim::calls systemctl
  assert_output --partial 'disable --now --system --quiet foo.service'
}

# ---------- restart_user_service_if_enabled ----------

@test "restart_user_service_if_enabled: restarts when enabled and confirm=y" {
  install_systemctl_shim
  export UNIT_EXISTS=1
  export UNIT_ENABLED=1
  export SCRIPTS_AUTO_ANSWER=y
  run systemctl::restart_user_service_if_enabled 'foo.service'
  assert_success
  run cli_shim::calls systemctl
  assert_output --partial 'restart --user --quiet foo.service'
}

@test "restart_user_service_if_enabled: skips when not enabled" {
  install_systemctl_shim
  export UNIT_EXISTS=1
  export UNIT_ENABLED=0
  export SCRIPTS_AUTO_ANSWER=y
  run systemctl::restart_user_service_if_enabled 'foo.service'
  assert_success
  run cli_shim::calls systemctl
  refute_output --partial 'restart --user'
}

# ---------- restart_system_service_if_enabled ----------

@test "restart_system_service_if_enabled: restarts via sudo when enabled, confirm=y" {
  install_systemctl_shim
  export UNIT_EXISTS=1
  export UNIT_ENABLED=1
  export SCRIPTS_AUTO_ANSWER=y
  run systemctl::restart_system_service_if_enabled 'foo.service'
  assert_success
  run cli_shim::calls systemctl
  assert_output --partial 'restart --system --quiet foo.service'
}

# ---------- arg-count guards ----------

@test "all 8 fns: die with no args" {
  for fn in user_service_unit_file_exists system_service_unit_file_exists \
    enable_user_service_unit enable_system_service_unit \
    disable_user_service_unit disable_system_service_unit \
    restart_user_service_if_enabled restart_system_service_if_enabled; do
    run "systemctl::${fn}"
    assert_failure
    assert_output --partial 'Expected exactly 1 argument'
  done
}
