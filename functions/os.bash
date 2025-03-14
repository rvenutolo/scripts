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

function is_arch() {
  check_no_args "$@"
  [[ "$(os_id)" == 'arch' ]]
}

function is_manjaro() {
  check_no_args "$@"
  [[ "$(os_id)" == 'manjaro' ]]
}

function is_endeavour() {
  check_no_args "$@"
  [[ "$(os_id)" == 'endeavouros' ]]
}

function is_fedora() {
  check_no_args "$@"
  [[ "$(os_id)" == 'fedora' ]]
}

function is_debian() {
  check_no_args "$@"
  [[ "$(os_id)" == 'debian' ]]
}

function is_ubuntu() {
  check_no_args "$@"
  [[ "$(os_id)" == 'ubuntu' ]]
}

function is_pop() {
  check_no_args "$@"
  [[ "$(os_id)" == 'pop' ]]
}

function is_leap() {
  check_no_args "$@"
  [[ "$(os_id)" == 'opensuse-leap' ]]
}

function is_tumbleweed() {
  check_no_args "$@"
  [[ "$(os_id)" == 'opensuse-tumbleweed' ]]
}
