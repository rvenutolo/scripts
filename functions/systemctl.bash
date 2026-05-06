#!/usr/bin/env bash

# Return true if a user systemd unit file with the given name exists.
# $1 = service unit file name (e.g. "foo.service")
function systemctl::user_service_unit_file_exists() {
  args::check_exactly_1_arg "$@"
  systemctl --user list-unit-files --all --quiet "$1" > '/dev/null'
}

# Return true if a system systemd unit file with the given name exists.
# $1 = service unit file name (e.g. "foo.service")
function systemctl::system_service_unit_file_exists() {
  args::check_exactly_1_arg "$@"
  systemctl --system list-unit-files --all --quiet "$1" > '/dev/null'
}

# Enable and start a user systemd service if its unit file exists and it is not already enabled.
# $1 = service unit file name (e.g. "foo.service")
function systemctl::enable_user_service_unit() {
  args::check_exactly_1_arg "$@"
  if systemctl::user_service_unit_file_exists "$1"; then
    if ! systemctl is-enabled --user --quiet "$1" && prompt::yn "Enable and start $1 user service?"; then
      log::log "Enabling and starting $1 user service"
      systemctl enable --now --user --quiet "$1"
      log::log "Enabled and started $1 user service"
    fi
  else
    log::log "User service unit files does not exist: $1"
  fi
}

# Enable and start a system systemd service if its unit file exists and it is not already enabled.
# $1 = service unit file name (e.g. "foo.service")
function systemctl::enable_system_service_unit() {
  args::check_exactly_1_arg "$@"
  if systemctl::system_service_unit_file_exists "$1"; then
    if ! systemctl is-enabled --system --quiet "$1" && prompt::yn "Enable and start $1 system service?"; then
      log::log "Enabling and starting $1 system service"
      sudo systemctl enable --now --system --quiet "$1"
      log::log "Enabled and started $1 system service"
    fi
  else
    log::log "System service unit files does not exist: $1"
  fi
}

# Disable and stop a user systemd service if its unit file exists and it is currently enabled.
# $1 = service unit file name (e.g. "foo.service")
function systemctl::disable_user_service_unit() {
  args::check_exactly_1_arg "$@"
  if systemctl::user_service_unit_file_exists "$1"; then
    if systemctl is-enabled --user --quiet "$1" && prompt::yn "Disable and stop $1 user service?"; then
      log::log "Disabling and stopping $1 user service"
      systemctl disable --now --user --quiet "$1"
      log::log "Disabled and stopped $1 user service"
    fi
  else
    log::log "User service unit files does not exist: $1"
  fi
}

# Disable and stop a system systemd service if its unit file exists and it is currently enabled.
# $1 = service unit file name (e.g. "foo.service")
function systemctl::disable_system_service_unit() {
  args::check_exactly_1_arg "$@"
  if systemctl::system_service_unit_file_exists "$1"; then
    if systemctl is-enabled --system --quiet "$1" && prompt::yn "Disable and stop $1 system service?"; then
      log::log "Disabling and stopping $1 system service"
      sudo systemctl disable --now --system --quiet "$1"
      log::log "Disabled and stopped $1 system service"
    fi
  else
    log::log "System service unit files does not exist: $1"
  fi
}

# Restart a user systemd service if its unit file exists and it is currently enabled.
# $1 = service unit file name (e.g. "foo.service")
function systemctl::restart_user_service_if_enabled() {
  args::check_exactly_1_arg "$@"
  if systemctl::user_service_unit_file_exists "$1"; then
    if systemctl is-enabled --user --quiet "$1" && prompt::yn "Restart $1 user service?"; then
      log::log "Restarting $1 user service"
      systemctl restart --user --quiet "$1"
      log::log "Restarted $1 user service"
    fi
  else
    log::log "User service unit files does not exist: $1"
  fi
}

# Restart a system systemd service if its unit file exists and it is currently enabled.
# $1 = service unit file name (e.g. "foo.service")
function systemctl::restart_system_service_if_enabled() {
  args::check_exactly_1_arg "$@"
  if systemctl::system_service_unit_file_exists "$1"; then
    if systemctl is-enabled --system --quiet "$1" && prompt::yn "Restart $1 system service?"; then
      log::log "Restarting $1 system service"
      sudo systemctl restart --system --quiet "$1"
      log::log "Restarted $1 system service"
    fi
  else
    log::log "System service unit files does not exist: $1"
  fi
}
