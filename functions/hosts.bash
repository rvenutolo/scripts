#!/usr/bin/env bash

#shellcheck disable=SC2120
function is_personal() {
  check_no_args "$@"
  [[ "$(hostname)" == "${PERSONAL_DESKTOP_HOSTNAME}" || "$(hostname)" == "${PERSONAL_LAPTOP_HOSTNAME}" ]]
}

#shellcheck disable=SC2120
function is_work() {
  check_no_args "$@"
  [[ "$(hostname)" == "${WORK_LAPTOP_HOSTNAME}" ]]
}

#shellcheck disable=SC2120
function is_desktop() {
  check_no_args "$@"
  [[ "$(hostname)" == "${PERSONAL_DESKTOP_HOSTNAME}" ]]
}

#shellcheck disable=SC2120
function is_laptop() {
  check_no_args "$@"
  [[ "$(hostname)" == "${PERSONAL_LAPTOP_HOSTNAME}" || "$(hostname)" == "${WORK_LAPTOP_HOSTNAME}" ]]
}

#shellcheck disable=SC2120
function is_server() {
  check_no_args "$@"
  [[ "$(hostname)" != "${PERSONAL_DESKTOP_HOSTNAME}" && "$(hostname)" != "${PERSONAL_LAPTOP_HOSTNAME}" && "$(hostname)" != "${WORK_LAPTOP_HOSTNAME}" ]]
}
