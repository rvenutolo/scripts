#!/usr/bin/env bash

#source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)/../lib/functions.sh"

function log() {
  echo "${0##*/}: $*" >&2
}

function check_no_args() {
  if [[ "$#" -ne 0 ]]; then
    log "Expected no arguments"
    exit 2
  fi
}

function check_at_most_1_arg() {
  if [[ "$#" -gt 1 ]]; then
    log "Expected at most 1 argument"
    exit 2
  fi
}

function check_exactly_1_arg() {
  if [[ "$#" -ne 1 ]]; then
    log "Expected exactly 1 argument"
    exit 2
  fi
}

function check_at_least_1_arg() {
  if [[ "$#" -lt 1 ]]; then
    log "Expected at least 1 argument"
    exit 2
  fi
}

function check_at_most_2_args() {
  if [[ "$#" -gt 2 ]]; then
    log "Expected at most 2 arguments"
    exit 2
  fi
}

function check_exactly_2_args() {
  if [[ "$#" -ne 2 ]]; then
    log "Expected exactly 2 arguments"
    exit 2
  fi
}

function check_at_least_2_args() {
  if [[ "$#" -lt 2 ]]; then
    log "Expected at least 2 arguments"
    exit 2
  fi
}

function check_for_stdin() {
  if [[ -t 0 ]]; then
    log "Expected STDIN"
    exit 2
  fi
}

function check_for_var() {
  check_exactly_1_arg "$@"
  readonly var_name="$1"
  if [[ -z "${!var_name-}" ]]; then
    log "${var_name} not set"
    exit 2
  fi
}

function check_is_root() {
  check_no_args
  if [[ "${EUID}" != '0' ]]; then
    log 'Must run as root'
    exit 2
  fi
}

function is_readable_file() {
  check_exactly_1_arg "$@"
  local file="$1"
  [[ -f "${file}" && -r "${file}" ]]
}

function executable_exists() {
  check_exactly_1_arg "$@"
  local executable="$1"
  # executables / no builtins, aliases, or functions
  type -aPf "${executable}" > /dev/null 2>&1
}

function command_exists() {
  check_exactly_1_arg "$@"
  local command="$1"
  # executables and builtins / no aliases or functions
  type -Pf "${command}" > /dev/null 2>&1
}

function is_arch() {
  check_no_args "$@"
  grep --quiet '^ID=arch$\|^ID_LIKE=arch$' '/etc/os-release'
}

function path_remove() {
  check_exactly_1_arg "$@"
  local path_to_remove="$1"
  PATH=$(echo -n "$PATH" | awk -v RS=: -v ORS=: '$0 != "'"${path_to_remove}"'"' | sed 's/:$//')
}

function path_append() {
  check_exactly_1_arg "$@"
  local path_to_append="$1"
  path_remove "${path_to_append}" && PATH="$PATH:${path_to_append}"
}

function path_prepend() {
  check_exactly_1_arg "$@"
  local path_to_prepend="$1"
  path_remove "${path_to_prepend}" && PATH="${path_to_prepend}:$PATH"
}

function contains_word() {
  # expected to pipe to this function
  check_exactly_1_arg "$@"
  check_for_stdin
  local word="$1"
  grep --quiet --fixed-strings --ignore-case --word-regex "${word}"
}

function is_distro() {
  check_exactly_1_arg "$@"
  local distro="$1"
  hostnamectl | grep --fixed-strings 'Operating System:' | cut --delimiter=':' --fields=2 | contains_word "${distro}"
}

function is_desktop_env() {
  check_exactly_1_arg "$@"
  local de="$1"
  echo "${XDG_CURRENT_DESKTOP-}" | contains_word "${de}"
}

function is_personal() {
  check_no_args "$@"
  [[ "${PERSONAL_OR_WORK-}" == 'personal' ]]
}

function is_work() {
  check_no_args "$@"
  [[ "${PERSONAL_OR_WORK-}" == 'work' ]]
}

function is_desktop() {
  check_no_args "$@"
  [[ "${DESKTOP_OR_LAPTOP-}" == 'desktop' ]]
}

function is_laptop() {
  check_no_args "$@"
  [[ "${DESKTOP_OR_LAPTOP-}" == 'laptop' ]]
}

function is_headless() {
  check_no_args "$@"
  [[ "${HEADLESS-}" == 'yes' ]]
}

function prompt_ny() {
  check_exactly_1_arg "$@"
  local question="$1"
  local prompt_reply=''
  while [[ "${prompt_reply}" != 'y' && "${prompt_reply}" != 'n' ]]; do
    read -rp "${question} [Y/n]: " prompt_reply
    if [[ ${prompt_reply} == [yY] ]]; then
      prompt_reply='y'
    elif [[ "${prompt_reply}" == '' || "${prompt_reply}" == [nN] ]]; then
      prompt_reply='n'
    fi
  done
  [[ "${prompt_reply}" == 'y' ]]
}

function prompt_yn() {
  check_exactly_1_arg "$@"
  local question="$1"
  local prompt_reply=''
  while [[ "${prompt_reply}" != 'y' && "${prompt_reply}" != 'n' ]]; do
    read -rp "${question} [Y/n]: " prompt_reply
    if [[ "${prompt_reply}" == '' || ${prompt_reply} == [yY] ]]; then
      prompt_reply='y'
    elif [[ "${prompt_reply}" == [nN] ]]; then
      prompt_reply='n'
    fi
  done
  [[ "${prompt_reply}" == 'y' ]]
}

function prompt_for_value() {
  check_exactly_2_args "$@"
  local question="$1"
  local default_value="$2"
  read -rp "${question} [${default_value}]: " prompt_reply
  if [[ -z "${prompt_reply}" ]]; then
    echo "${default_value}"
  else
    echo "${prompt_reply}"
  fi
}


