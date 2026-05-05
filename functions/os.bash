#!/usr/bin/env bash

# $1 = field name from /etc/os-release (e.g. ID, VERSION_CODENAME)
function os_release_field() {
  check_exactly_1_arg "$@"
  (
    # shellcheck disable=SC1091
    source '/etc/os-release'
    printf '%s\n' "${!1:-}"
  )
}

#shellcheck disable=SC2120
function os_id() {
  check_no_args "$@"
  os_release_field 'ID'
}

#shellcheck disable=SC2120
function os_codename() {
  check_no_args "$@"
  os_release_field 'VERSION_CODENAME'
}

#shellcheck disable=SC2120
function os_arch() {
  check_no_args "$@"
  dpkg --print-architecture
}

#shellcheck disable=SC2120
function is_arch() {
  check_no_args "$@"
  [[ "$(os_id)" == 'arch' ]]
}

#shellcheck disable=SC2120
function is_cachyos() {
  check_no_args "$@"
  [[ "$(os_id)" == 'cachyos' ]]
}

#shellcheck disable=SC2120
function is_fedora() {
  check_no_args "$@"
  [[ "$(os_id)" == 'fedora' ]]
}

#shellcheck disable=SC2120
function is_debian() {
  check_no_args "$@"
  [[ "$(os_id)" == 'debian' ]]
}

#shellcheck disable=SC2120
function is_ubuntu() {
  check_no_args "$@"
  [[ "$(os_id)" == 'ubuntu' ]]
}

#shellcheck disable=SC2120
function is_leap() {
  check_no_args "$@"
  [[ "$(os_id)" == 'opensuse-leap' ]]
}

#shellcheck disable=SC2120
function is_tumbleweed() {
  check_no_args "$@"
  [[ "$(os_id)" == 'opensuse-tumbleweed' ]]
}
