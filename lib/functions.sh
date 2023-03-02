#!/usr/bin/env bash

#source "${SCRIPTS_DIR}/lib/functions.sh"

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

function check_exactly_3_args() {
  if [[ "$#" -ne 3 ]]; then
    log "Expected exactly 3 arguments"
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

function enable_service() {
  check_exactly_3_args "$@"
  local service_unit="$1"
  local service_desc="$2"
  local system_or_user="$3"
  if ! systemctl is-enabled --"${system_or_user}" --quiet "${service_unit}" && prompt_yn "Enable and start ${service_desc} service?"; then
    log "Enabling and starting ${service_desc} service"
    systemctl enable --now --"${system_or_user}" --quiet "${service_unit}"
    log "Enabled and started ${service_desc} service"
  fi
  if ! systemctl is-active --"${system_or_user}" --quiet "${service_unit}" && prompt_yn "Start ${service_desc} service?"; then
    log "Starting ${service_desc} service"
    systemctl start --"${system_or_user}" --quiet "${service_unit}"
    log "Started ${service_desc} service"
  fi
}

function link_file() {
  check_exactly_2_args "$@"
  local target_file="$1"
  local link_file="$2"
  if [[ -f "${target_file}" ]]; then
    log "${target_file} does not exist"
    exit 0
  fi
  if [[ -L "${link_file}" && "$(readlink --canonicalize "${link_file}")" == "$(readlink --canonicalize "${target_file}")" ]]; then
    exit 0
  fi
  if [[ -f "${link_file}" ]]; then
    diff --color --unified "${link_file}" "${target_file}" || true
    if ! prompt_yn "${link_file} exists - Link: ${target_file} -> ${link_file}?"; then
      exit 0
    fi
  else
    if ! prompt_yn "Link: ${target_file} -> ${link_file}?"; then
      exit 0
    fi
  fi
  log "Linking: ${target_file} -> ${link_file}"
  if [[ -f "${link_file}" ]]; then
    sudo rm "${link_file}"
  fi
  sudo mkdir --parents "$(dirname "${link_file}")"
  sudo ln --symbolic "${target_file}" "${link_file}"
  log "Linked: ${target_file} -> ${link_file}"
}

function move_file() {
  check_exactly_2_args "$@"
  local old_file="$1"
  local new_file="$2"
  if [[ ! -f "${old_file}" ]]; then
    exit 0
  fi
  if [[ "${old_file}" == "${new_file}" ]]; then
    exit 0
  fi
  if ! prompt_yn "Move ${old_file} -> ${new_file}?"; then
    exit 0
  fi
  log "Moving: ${old_file} -> ${new_file}"
  mkdir --parents "$(dirname "${new_file}")"
  mv "${old_file}" "${new_file}"
  log "Moved: ${old_file} -> ${new_file}"
}
