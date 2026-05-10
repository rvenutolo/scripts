#!/usr/bin/env bash

# @description Return true if the current host is a personal machine (desktop or laptop).
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
# @exitcode 0 if true
# @exitcode 1 if false
function hosts::is_personal() {
  args::check_no_args "$@"
  [[ "$(hostname)" == "${PERSONAL_DESKTOP_HOSTNAME}" || "$(hostname)" == "${PERSONAL_LAPTOP_HOSTNAME}" ]]
}

# @description Return true if the current host is the work laptop.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
# @exitcode 0 if true
# @exitcode 1 if false
function hosts::is_work() {
  args::check_no_args "$@"
  [[ "$(hostname)" == "${WORK_LAPTOP_HOSTNAME}" ]]
}

# @description Return true if the current host is the personal desktop.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
# @exitcode 0 if true
# @exitcode 1 if false
function hosts::is_desktop() {
  args::check_no_args "$@"
  [[ "$(hostname)" == "${PERSONAL_DESKTOP_HOSTNAME}" ]]
}

# @description Return true if the current host is a laptop (personal or work).
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
# @exitcode 0 if true
# @exitcode 1 if false
function hosts::is_laptop() {
  args::check_no_args "$@"
  [[ "$(hostname)" == "${PERSONAL_LAPTOP_HOSTNAME}" || "$(hostname)" == "${WORK_LAPTOP_HOSTNAME}" ]]
}

# @description Return true if the current host is a server (not any known personal or work machine).
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
# @exitcode 0 if true
# @exitcode 1 if false
function hosts::is_server() {
  args::check_no_args "$@"
  [[ "$(hostname)" != "${PERSONAL_DESKTOP_HOSTNAME}" &&
  "$(hostname)" != "${PERSONAL_LAPTOP_HOSTNAME}" &&
  "$(hostname)" != "${WORK_LAPTOP_HOSTNAME}" ]]
}
