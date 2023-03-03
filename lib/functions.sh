#!/usr/bin/env bash

#source "${SCRIPTS_DIR}/lib/functions.sh"

function log() {
  echo "[$(date '+%T')] ${0##*/}: $*" >&2
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
  local _file="$1"
  [[ -f "${_file}" && -r "${_file}" ]]
}

function executable_exists() {
  check_exactly_1_arg "$@"
  local _executable="$1"
  # executables / no builtins, aliases, or functions
  type -aPf "${_executable}" > /dev/null 2>&1
}

function command_exists() {
  check_exactly_1_arg "$@"
  local _command="$1"
  # executables and builtins / no aliases or functions
  type -Pf "${_command}" > /dev/null 2>&1
}

function is_arch() {
  check_no_args "$@"
  grep --quiet '^ID=arch$\|^ID_LIKE=arch$' '/etc/os-release'
}

function path_remove() {
  check_exactly_1_arg "$@"
  local _path_to_remove="$1"
  PATH=$(echo -n "$PATH" | awk -v RS=: -v ORS=: '$0 != "'"${_path_to_remove}"'"' | sed 's/:$//')
}

function path_append() {
  check_exactly_1_arg "$@"
  local _path_to_append="$1"
  path_remove "${_path_to_append}" && PATH="$PATH:${_path_to_append}"
}

function path_prepend() {
  check_exactly_1_arg "$@"
  local _path_to_prepend="$1"
  path_remove "${_path_to_prepend}" && PATH="${_path_to_prepend}:$PATH"
}

function contains_word() {
  # expected to pipe to this function
  check_exactly_1_arg "$@"
  check_for_stdin
  local _word="$1"
  grep --quiet --fixed-strings --ignore-case --word-regex "${_word}"
}

function is_distro() {
  check_exactly_1_arg "$@"
  local _distro="$1"
  hostnamectl | grep --fixed-strings 'Operating System:' | cut --delimiter=':' --fields=2 | contains_word "${_distro}"
}

function is_desktop_env() {
  check_exactly_1_arg "$@"
  local _de="$1"
  echo "${XDG_CURRENT_DESKTOP-}" | contains_word "${_de}"
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
  local _question="$1"
  local _prompt_reply=''
  while [[ "${_prompt_reply}" != 'y' && "${_prompt_reply}" != 'n' ]]; do
    read -rp "${_question} [Y/n]: " _prompt_reply
    if [[ ${_prompt_reply} == [yY] ]]; then
      _prompt_reply='y'
    elif [[ "${_prompt_reply}" == '' || "${_prompt_reply}" == [nN] ]]; then
      _prompt_reply='n'
    fi
  done
  [[ "${_prompt_reply}" == 'y' ]]
}

function prompt_yn() {
  check_exactly_1_arg "$@"
  local _question="$1"
  local _prompt_reply=''
  while [[ "${_prompt_reply}" != 'y' && "${_prompt_reply}" != 'n' ]]; do
    read -rp "${_question} [Y/n]: " _prompt_reply
    if [[ "${_prompt_reply}" == '' || ${_prompt_reply} == [yY] ]]; then
      _prompt_reply='y'
    elif [[ "${_prompt_reply}" == [nN] ]]; then
      _prompt_reply='n'
    fi
  done
  [[ "${_prompt_reply}" == 'y' ]]
}

function prompt_for_value() {
  check_exactly_2_args "$@"
  local _question="$1"
  local _default_value="$2"
  read -rp "${_question} [${_default_value}]: " _prompt_reply
  if [[ -z "${_prompt_reply}" ]]; then
    echo "${_default_value}"
  else
    echo "${_prompt_reply}"
  fi
}

function enable_service() {
  check_exactly_3_args "$@"
  local _service_unit="$1"
  local _service_desc="$2"
  local _system_or_user="$3"
  if ! systemctl is-enabled --"${_system_or_user}" --quiet "${_service_unit}" && prompt_yn "Enable and start ${_service_desc} service?"; then
    log "Enabling and starting ${_service_desc} service"
    systemctl enable --now --"${_system_or_user}" --quiet "${_service_unit}"
    log "Enabled and started ${_service_desc} service"
  fi
  if ! systemctl is-active --"${_system_or_user}" --quiet "${_service_unit}" && prompt_yn "Start ${_service_desc} service?"; then
    log "Starting ${_service_desc} service"
    systemctl start --"${_system_or_user}" --quiet "${_service_unit}"
    log "Started ${_service_desc} service"
  fi
}

function link_file() {
  check_exactly_2_args "$@"
  local _target_file="$1"
  local _link_file="$2"
  if [[ ! -f "${_target_file}" ]]; then
    log "${_target_file} does not exist"
    exit 0
  fi
  if [[ -L "${link_file}" && "$(readlink --canonicalize "${link_file}")" == "$(readlink --canonicalize "${_target_file}")" ]]; then
    exit 0
  fi
  if [[ -f "${link_file}" ]]; then
    diff --color --unified "${link_file}" "${_target_file}" || true
    if ! prompt_yn "${link_file} exists - Link: ${_target_file} -> ${link_file}?"; then
      exit 0
    fi
  else
    if ! prompt_yn "Link: ${_target_file} -> ${link_file}?"; then
      exit 0
    fi
  fi
  log "Linking: ${_target_file} -> ${link_file}"
  if [[ -f "${link_file}" ]]; then
    sudo rm "${link_file}"
  fi
  sudo mkdir --parents "$(dirname "${link_file}")"
  sudo ln --symbolic "${_target_file}" "${link_file}"
  log "Linked: ${_target_file} -> ${link_file}"
}

function move_file() {
  check_exactly_2_args "$@"
  local _old_file="$1"
  local _new_file="$2"
  if [[ ! -f "${_old_file}" ]]; then
    exit 0
  fi
  if [[ "${_old_file}" == "${_new_file}" ]]; then
    exit 0
  fi
  if ! prompt_yn "Move ${_old_file} -> ${_new_file}?"; then
    exit 0
  fi
  log "Moving: ${_old_file} -> ${_new_file}"
  mkdir --parents "$(dirname "${_new_file}")"
  mv "${_old_file}" "${_new_file}"
  log "Moved: ${_old_file} -> ${_new_file}"
}

function ipv4_to_num() {
  IFS=. read -r a b c d <<< "$*"
  printf '%d\n' "$((a * 256 ** 3 + b * 256 ** 2 + c * 256 + d))"
}
