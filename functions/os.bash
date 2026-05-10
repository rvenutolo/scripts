#!/usr/bin/env bash

# @description Print the value of a named field from /etc/os-release.
# Output: stdout — field value, or empty string if the field is absent
# @arg $1 field name (e.g. ID, VERSION_CODENAME)
function os::release_field() {
  args::check_exactly_1_arg "$@"
  (
    # shellcheck disable=SC1091 # /etc/os-release is sourced dynamically and not statically followable
    source '/etc/os-release'
    printf '%s\n' "${!1:-}"
  )
}

# @description Print the OS identifier from /etc/os-release (e.g. "ubuntu", "fedora").
# Output: stdout — value of the ID field
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function os::id() {
  args::check_no_args "$@"
  os::release_field 'ID'
}

# @description Print the OS version codename from /etc/os-release (e.g. "jammy").
# Output: stdout — value of the VERSION_CODENAME field
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function os::codename() {
  args::check_no_args "$@"
  os::release_field 'VERSION_CODENAME'
}

# @description Print the system architecture as reported by dpkg (e.g. "amd64").
# Output: stdout — dpkg architecture string
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function os::arch() {
  args::check_no_args "$@"
  dpkg --print-architecture
}

# @description Return true if the current OS is Arch Linux.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function os::is_arch() {
  args::check_no_args "$@"
  [[ "$(os::id)" == 'arch' ]]
}

# @description Return true if the current OS is CachyOS.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function os::is_cachyos() {
  args::check_no_args "$@"
  [[ "$(os::id)" == 'cachyos' ]]
}

# @description Return true if the current OS is Fedora.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function os::is_fedora() {
  args::check_no_args "$@"
  [[ "$(os::id)" == 'fedora' ]]
}

# @description Return true if the current OS is Debian.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function os::is_debian() {
  args::check_no_args "$@"
  [[ "$(os::id)" == 'debian' ]]
}

# @description Return true if the current OS is Ubuntu.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function os::is_ubuntu() {
  args::check_no_args "$@"
  [[ "$(os::id)" == 'ubuntu' ]]
}

# @description Return true if the current OS is openSUSE Leap.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function os::is_leap() {
  args::check_no_args "$@"
  [[ "$(os::id)" == 'opensuse-leap' ]]
}

# @description Return true if the current OS is openSUSE Tumbleweed.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function os::is_tumbleweed() {
  args::check_no_args "$@"
  [[ "$(os::id)" == 'opensuse-tumbleweed' ]]
}
