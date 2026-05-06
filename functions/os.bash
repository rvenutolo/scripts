#!/usr/bin/env bash

# $1 = field name from /etc/os-release (e.g. ID, VERSION_CODENAME)
function os::release_field() {
  args::check_exactly_1_arg "$@"
  (
    # shellcheck disable=SC1091
    source '/etc/os-release'
    printf '%s\n' "${!1:-}"
  )
}

#shellcheck disable=SC2120
function os::id() {
  args::check_no_args "$@"
  os::release_field 'ID'
}

#shellcheck disable=SC2120
function os::codename() {
  args::check_no_args "$@"
  os::release_field 'VERSION_CODENAME'
}

#shellcheck disable=SC2120
function os::arch() {
  args::check_no_args "$@"
  dpkg --print-architecture
}

#shellcheck disable=SC2120
function os::is_arch() {
  args::check_no_args "$@"
  [[ "$(os::id)" == 'arch' ]]
}

#shellcheck disable=SC2120
function os::is_cachyos() {
  args::check_no_args "$@"
  [[ "$(os::id)" == 'cachyos' ]]
}

#shellcheck disable=SC2120
function os::is_fedora() {
  args::check_no_args "$@"
  [[ "$(os::id)" == 'fedora' ]]
}

#shellcheck disable=SC2120
function os::is_debian() {
  args::check_no_args "$@"
  [[ "$(os::id)" == 'debian' ]]
}

#shellcheck disable=SC2120
function os::is_ubuntu() {
  args::check_no_args "$@"
  [[ "$(os::id)" == 'ubuntu' ]]
}

#shellcheck disable=SC2120
function os::is_leap() {
  args::check_no_args "$@"
  [[ "$(os::id)" == 'opensuse-leap' ]]
}

#shellcheck disable=SC2120
function os::is_tumbleweed() {
  args::check_no_args "$@"
  [[ "$(os::id)" == 'opensuse-tumbleweed' ]]
}
