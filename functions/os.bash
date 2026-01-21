#!/usr/bin/env bash

#shellcheck disable=SC2120
function os_id() {
  check_no_args "$@"
  grep --only-matching --perl-regexp '^ID=\K\w+$' '/etc/os-release'
}

#shellcheck disable=SC2120
function os_codename() {
  check_no_args "$@"
  grep --only-matching --perl-regexp '^VERSION_CODENAME=\K\w+$' '/etc/os-release'
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
function is_manjaro() {
  check_no_args "$@"
  [[ "$(os_id)" == 'manjaro' ]]
}

#shellcheck disable=SC2120
function is_endeavour() {
  check_no_args "$@"
  [[ "$(os_id)" == 'endeavouros' ]]
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
function is_pop() {
  check_no_args "$@"
  [[ "$(os_id)" == 'pop' ]]
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
