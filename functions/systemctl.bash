#!/usr/bin/env bash

# $1 = service unit file
function user_service_unit_file_exists() {
  check_exactly_1_arg "$@"
  systemctl --user list-unit-files --all --quiet "$1" > '/dev/null'
}

# $1 = service unit file
function system_service_unit_file_exists() {
  systemctl --system list-unit-files --all --quiet "$1" > '/dev/null'
}

# $1 = service unit file
function enable_user_service_unit() {
  check_exactly_1_arg "$@"
  if user_service_unit_file_exists "$1"; then
    if ! systemctl is-enabled --user --quiet "$1" && prompt_yn "Enable and start $1 user service?"; then
      log "Enabling and starting $1 user service"
      systemctl enable --now --user --quiet "$1"
      log "Enabled and started $1 user service"
    fi
  else
    log "User service unit files does not exist: $1"
  fi
}

# $1 = service unit file
function enable_system_service_unit() {
  check_exactly_1_arg "$@"
  if system_service_unit_file_exists "$1"; then
    if ! systemctl is-enabled --system --quiet "$1" && prompt_yn "Enable and start $1 system service?"; then
      log "Enabling and starting $1 system service"
      sudo systemctl enable --now --system --quiet "$1"
      log "Enabled and started $1 system service"
    fi
  else
    log "System service unit files does not exist: $1"
  fi
}

# $1 = service unit file
function disable_user_service_unit() {
  check_exactly_1_arg "$@"
  if user_service_unit_file_exists "$1"; then
    if systemctl is-enabled --user --quiet "$1" && prompt_yn "Disable and stop $1 user service?"; then
      log "Disabling and stopping $1 user service"
      systemctl disable --now --user --quiet "$1"
      log "Disabled and stopped $1 user service"
    fi
  else
    log "User service unit files does not exist: $1"
  fi
}

# $1 = service unit file
function disable_system_service_unit() {
  check_exactly_1_arg "$@"
  if system_service_unit_file_exists "$1"; then
    if systemctl is-enabled --system --quiet "$1" && prompt_yn "Disable and stop $1 system service?"; then
      log "Disabling and stopping $1 system service"
      sudo systemctl disable --now --system --quiet "$1"
      log "Disabled and stopped $1 system service"
    fi
  else
    log "System service unit files does not exist: $1"
  fi
}

# $1 = service unit file
function restart_user_service_if_enabled() {
  check_exactly_1_arg "$@"
  if user_service_unit_file_exists "$1"; then
    if systemctl is-enabled --user --quiet "$1" && prompt_yn "Restart $1 user service?"; then
      log "Restarting $1 user service"
      systemctl restart --user --quiet "$1"
      log "Restarted $1 user service"
    fi
  else
    log "User service unit files does not exist: $1"
  fi
}

# $1 = service unit file
function restart_system_service_if_enabled() {
  check_exactly_1_arg "$@"
  if system_service_unit_file_exists "$1"; then
    if systemctl is-enabled --system --quiet "$1" && prompt_yn "Restart $1 system service?"; then
      log "Restarting $1 system service"
      sudo systemctl restart --system --quiet "$1"
      log "Restarted $1 system service"
    fi
  else
    log "System service unit files does not exist: $1"
  fi
}
