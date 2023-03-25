#!/usr/bin/env bash

#source "${SCRIPTS_DIR}/lib/functions.bash"
#source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/functions.bash"

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

# $1 = variable name
function check_for_var() {
  check_exactly_1_arg "$@"
  if [[ -z "${!1-}" ]]; then
    log "$1 not set"
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

# $1 = file
function is_readable_file() {
  check_exactly_1_arg "$@"
  [[ -f "$1" && -r "$1" ]]
}

# $1 = executable
function executable_exists() {
  check_exactly_1_arg "$@"
  # executables / no builtins, aliases, or functions
  type -aPf "$1" > /dev/null 2>&1
}

# $1 = command
function command_exists() {
  check_exactly_1_arg "$@"
  # executables and builtins / no aliases or functions
  type -Pf "$1" > /dev/null 2>&1
}

function os_id() {
  check_no_args "$@"
  grep --only-matching --perl-regexp '^ID=\K\w+$' '/etc/os-release'
}

function is_arch() {
  check_no_args "$@"
  [[ "$(os_id)" == 'arch' ]]
}

function is_manjaro() {
  check_no_args "$@"
  [[ "$(os_id)" == 'manjaro' ]]
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

# $1 = path to remove
function path_remove() {
  check_exactly_1_arg "$@"
  PATH=$(echo -n "$PATH" | awk -v RS=: -v ORS=: '$0 != "'"$1"'"' | sed 's/:$//')
}

# $1 = path to append
function path_append() {
  check_exactly_1_arg "$@"
  path_remove "$1" && PATH="$PATH:$1"
}

# $1 = path to prepend
function path_prepend() {
  check_exactly_1_arg "$@"
  path_remove "$1" && PATH="$1:$PATH"
}

# expected to pipe to this function, ex: groups | contains_word 'wheel'
# $1 = word
function contains_word() {
  # expected to pipe to this function
  check_exactly_1_arg "$@"
  check_for_stdin
  grep --quiet --fixed-strings --ignore-case --word-regex "$1"
}

# $1 = env
function is_desktop_env() {
  check_exactly_1_arg "$@"
  echo "${XDG_CURRENT_DESKTOP-}" | contains_word "$1"
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

# $1 = question
function prompt_ny() {
  check_exactly_1_arg "$@"
  REPLY=''
  while [[ "${REPLY}" != 'y' && "${REPLY}" != 'n' ]]; do
    read -rp "$1 [Y/n]: "
    if [[ ${REPLY} == [yY] ]]; then
      REPLY='y'
    elif [[ "${REPLY}" == '' || "${REPLY}" == [nN] ]]; then
      REPLY='n'
    fi
  done
  [[ "${REPLY}" == 'y' ]]
}

# $1 = question
function prompt_yn() {
  check_exactly_1_arg "$@"
  REPLY=''
  while [[ "${REPLY}" != 'y' && "${REPLY}" != 'n' ]]; do
    read -rp "$1 [Y/n]: "
    if [[ "${REPLY}" == '' || ${REPLY} == [yY] ]]; then
      REPLY='y'
    elif [[ "${REPLY}" == [nN] ]]; then
      REPLY='n'
    fi
  done
  [[ "${REPLY}" == 'y' ]]
}

# $1 = question
# $2 = default value
function prompt_for_value() {
  check_exactly_2_args "$@"
  REPLY=''
  read -rp "$1 [$2]: "
  if [[ -z "${REPLY}" ]]; then
    echo "$2"
  else
    echo "${REPLY}"
  fi
}

# $1 = target file
# $2 = link file
function link_file() {
  check_exactly_2_args "$@"
  if [[ ! -f "$1" ]]; then
    log "$1 does not exist"
    exit 0
  fi
  if [[ -L "$2" && "$(readlink --canonicalize "$2")" == "$(readlink --canonicalize "$1")" ]]; then
    exit 0
  fi
  if [[ -f "$2" ]]; then
    diff --color --unified "$2" "$1" || true
    if ! prompt_yn "$2 exists - Link: $1 -> $2?"; then
      exit 0
    fi
  else
    if ! prompt_yn "Link: $1 -> $2?"; then
      exit 0
    fi
  fi
  log "Linking: $1 -> $2"
  if [[ -f "$2" ]]; then
    sudo rm "$2"
  fi
  sudo mkdir --parents "$(dirname "$2")"
  sudo ln --symbolic "$1" "$2"
  log "Linked: $1 -> $2"
}

# $1 = old file location
# $2 = new file location
function move_file() {
  check_exactly_2_args "$@"
  if [[ ! -f "$1" ]]; then
    exit 0
  fi
  if [[ "$1" == "$2" ]]; then
    exit 0
  fi
  if ! prompt_yn "Move $1 -> $2?"; then
    exit 0
  fi
  log "Moving: $1 -> $2"
  mkdir --parents "$(dirname "$2")"
  mv "$1" "$2"
  log "Moved: $1 -> $2"
}

# $1 = ip
function ipv4_to_num() {
  check_exactly_1_arg "$@"
  IFS=. read -r a b c d <<< "$1"
  echo "$(((a << 24) + (b << 16) + (c << 8) + d))"
}

# $1 = ip
function num_to_ipv4() {
  check_exactly_1_arg "$@"
  echo "$(($1 >> 24 & 0xff)).$(($1 >> 16 & 0xff)).$(($1 >> 8 & 0xff)).$(($1 & 0xff))"
}

function local_ip() {
  check_no_args "$@"
  ip -oneline route get to '8.8.8.8' | sed --quiet 's/.*src \([0-9.]\+\).*/\1/p'
}

function local_network() {
  local local_ip_num="$(ipv4_to_num "$(local_ip)")"
  if [[ $(ipv4_to_num '10.0.0.0') -le "${local_ip_num}" && "${local_ip_num}" -le $(ipv4_to_num '10.255.255.255') ]]; then
    echo '10.0.0.0/8'
  elif [[ $(ipv4_to_num '172.16.0.0') -le "${local_ip_num}" && "${local_ip_num}" -le $(ipv4_to_num '172.31.255.255') ]]; then
    echo '172.16.0.0/12'
  elif [[ $(ipv4_to_num '192.168.0.0') -le "${local_ip_num}" && "${local_ip_num}" -le $(ipv4_to_num '192.168.255.255') ]]; then
    echo '192.168.0.0/16'
  else
    log "Could not determine local network IPv4 range"
    exit 2
  fi
}

# path_remove "$(this_script_dir)"
function this_script_dir() {
  cd -- "$(dirname -- "${BASH_SOURCE[1]}")" &> /dev/null && pwd
}
