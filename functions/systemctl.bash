#!/usr/bin/env bash

# @description Return true if a user systemd unit file with the given name exists.
# @arg $1 service unit file name (e.g. "foo.service")
function systemctl::user_service_unit_file_exists() {
  args::check_exactly_1_arg "$@"
  systemctl --user list-unit-files --all --quiet "$1" > '/dev/null'
}

# @description Return true if a system systemd unit file with the given name exists.
# @arg $1 service unit file name (e.g. "foo.service")
function systemctl::system_service_unit_file_exists() {
  args::check_exactly_1_arg "$@"
  systemctl --system list-unit-files --all --quiet "$1" > '/dev/null'
}

# @description Enable and start a user systemd service if its unit file exists and it is not already enabled.
# @arg $1 service unit file name (e.g. "foo.service")
function systemctl::enable_user_service_unit() {
  args::check_exactly_1_arg "$@"
  local -r unit="$1"
  if systemctl::user_service_unit_file_exists "${unit}"; then
    if ! systemctl is-enabled --user --quiet "${unit}" && prompt::yn "Enable and start ${unit} user service?"; then
      log::log "Enabling and starting ${unit} user service"
      systemctl enable --now --user --quiet "${unit}"
      log::log "Enabled and started ${unit} user service"
    fi
  else
    log::log "User service unit files does not exist: ${unit}"
  fi
}

# @description Enable and start a system systemd service if its unit file exists and it is not already enabled.
# @arg $1 service unit file name (e.g. "foo.service")
function systemctl::enable_system_service_unit() {
  args::check_exactly_1_arg "$@"
  local -r unit="$1"
  if systemctl::system_service_unit_file_exists "${unit}"; then
    if ! systemctl is-enabled --system --quiet "${unit}" && prompt::yn "Enable and start ${unit} system service?"; then
      log::log "Enabling and starting ${unit} system service"
      sudo systemctl enable --now --system --quiet "${unit}"
      log::log "Enabled and started ${unit} system service"
    fi
  else
    log::log "System service unit files does not exist: ${unit}"
  fi
}

# @description Disable and stop a user systemd service if its unit file exists and it is currently enabled.
# @arg $1 service unit file name (e.g. "foo.service")
function systemctl::disable_user_service_unit() {
  args::check_exactly_1_arg "$@"
  local -r unit="$1"
  if systemctl::user_service_unit_file_exists "${unit}"; then
    if systemctl is-enabled --user --quiet "${unit}" && prompt::yn "Disable and stop ${unit} user service?"; then
      log::log "Disabling and stopping ${unit} user service"
      systemctl disable --now --user --quiet "${unit}"
      log::log "Disabled and stopped ${unit} user service"
    fi
  else
    log::log "User service unit files does not exist: ${unit}"
  fi
}

# @description Disable and stop a system systemd service if its unit file exists and it is currently enabled.
# @arg $1 service unit file name (e.g. "foo.service")
function systemctl::disable_system_service_unit() {
  args::check_exactly_1_arg "$@"
  local -r unit="$1"
  if systemctl::system_service_unit_file_exists "${unit}"; then
    if systemctl is-enabled --system --quiet "${unit}" && prompt::yn "Disable and stop ${unit} system service?"; then
      log::log "Disabling and stopping ${unit} system service"
      sudo systemctl disable --now --system --quiet "${unit}"
      log::log "Disabled and stopped ${unit} system service"
    fi
  else
    log::log "System service unit files does not exist: ${unit}"
  fi
}

# @description Restart a user systemd service if its unit file exists and it is currently enabled.
# @arg $1 service unit file name (e.g. "foo.service")
function systemctl::restart_user_service_if_enabled() {
  args::check_exactly_1_arg "$@"
  local -r unit="$1"
  if systemctl::user_service_unit_file_exists "${unit}"; then
    if systemctl is-enabled --user --quiet "${unit}" && prompt::yn "Restart ${unit} user service?"; then
      log::log "Restarting ${unit} user service"
      systemctl restart --user --quiet "${unit}"
      log::log "Restarted ${unit} user service"
    fi
  else
    log::log "User service unit files does not exist: ${unit}"
  fi
}

# @description Restart a system systemd service if its unit file exists and it is currently enabled.
# @arg $1 service unit file name (e.g. "foo.service")
function systemctl::restart_system_service_if_enabled() {
  args::check_exactly_1_arg "$@"
  local -r unit="$1"
  if systemctl::system_service_unit_file_exists "${unit}"; then
    if systemctl is-enabled --system --quiet "${unit}" && prompt::yn "Restart ${unit} system service?"; then
      log::log "Restarting ${unit} system service"
      sudo systemctl restart --system --quiet "${unit}"
      log::log "Restarted ${unit} system service"
    fi
  else
    log::log "System service unit files does not exist: ${unit}"
  fi
}
