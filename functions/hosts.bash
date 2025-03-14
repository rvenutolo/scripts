#!/usr/bin/env bash

function is_personal() {
  check_no_args "$@"
  [[ "$(hostname)" == "${PERSONAL_DESKTOP_HOSTNAME}" || "$(hostname)" == "${PERSONAL_LAPTOP_HOSTNAME}" ]]
}

function is_work() {
  check_no_args "$@"
  [[ "$(hostname)" == "${WORK_LAPTOP_HOSTNAME}" ]]
}

function is_desktop() {
  check_no_args "$@"
  [[ "$(hostname)" == "${PERSONAL_DESKTOP_HOSTNAME}" ]]
}

function is_laptop() {
  check_no_args "$@"
  [[ "$(hostname)" == "${PERSONAL_LAPTOP_HOSTNAME}" || "$(hostname)" == "${WORK_LAPTOP_HOSTNAME}" ]]
}

function is_server() {
  check_no_args "$@"
  [[ "$(hostname)" != "${PERSONAL_DESKTOP_HOSTNAME}" && "$(hostname)" != "${PERSONAL_LAPTOP_HOSTNAME}" && "$(hostname)" != "${WORK_LAPTOP_HOSTNAME}" ]]
}
