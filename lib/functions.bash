#!/usr/bin/env bash

#source "${SCRIPTS_DIR}/lib/functions.bash"
#source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/functions.bash"

function log() {
  echo -e "[$(date +%T) ${0##*/}] $*" >&2
}

function die() {
  echo -e "DIE: $* (at ${BASH_SOURCE[1]}:${FUNCNAME[1]} line ${BASH_LINENO[0]}.)" >&2
  exit 1
}

function check_not_root() {
  if [[ "${EUID}" == 0 ]]; then
    die "Do not run this script as root"
  fi
}

function check_no_args() {
  if [[ "$#" -ne 0 ]]; then
    die "Expected no arguments"
  fi
}

function check_at_most_1_arg() {
  if [[ "$#" -gt 1 ]]; then
    die "Expected at most 1 argument"
  fi
}

function check_exactly_1_arg() {
  if [[ "$#" -ne 1 ]]; then
    die "Expected exactly 1 argument"
  fi
}

function check_at_least_1_arg() {
  if [[ "$#" -lt 1 ]]; then
    die "Expected at least 1 argument"
  fi
}

function check_at_most_2_args() {
  if [[ "$#" -gt 2 ]]; then
    die "Expected at most 2 arguments"
  fi
}

function check_exactly_2_args() {
  if [[ "$#" -ne 2 ]]; then
    die "Expected exactly 2 arguments"
  fi
}

function check_at_least_2_args() {
  if [[ "$#" -lt 2 ]]; then
    die "Expected at least 2 arguments"
  fi
}

function check_exactly_3_args() {
  if [[ "$#" -ne 3 ]]; then
    die "Expected exactly 3 arguments"
  fi
}

function check_exactly_4_args() {
  if [[ "$#" -ne 4 ]]; then
    die "Expected exactly 4 arguments"
  fi
}

function check_for_stdin() {
  if [[ -t 0 ]]; then
    die "Expected STDIN"
  fi
}

# $1 = variable name
function check_for_var() {
  check_exactly_1_arg "$@"
  if [[ -z "${!1:-}" ]]; then
    die "$1 not set"
  fi
}

function check_is_root() {
  check_no_args
  if [[ "${EUID}" != '0' ]]; then
    die 'Must run as root'
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
  ## remove from path so scripts that mask commands are no longer on PATH, ex: mvn
  path_remove "${SCRIPTS_DIR}/main"
  path_remove "${SCRIPTS_DIR}/other"
  # executables / no builtins, aliases, or functions
  type -aPf "$1" > /dev/null 2>&1
}

# $1 = command
function command_exists() {
  check_exactly_1_arg "$@"
  ## remove from path so scripts that mask commands are no longer on PATH, ex: mvn
  path_remove "${SCRIPTS_DIR}/main"
  path_remove "${SCRIPTS_DIR}/other"
  # executables and builtins / no aliases or functions
  type -Pf "$1" > /dev/null 2>&1
}

# $1 = function
function function_exists() {
  check_exactly_1_arg "$@"
  declare -f "$1" > /dev/null 2>&1
}

#shellcheck disable=SC2120
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
  echo "${XDG_CURRENT_DESKTOP:-}" | contains_word "$1"
}

function is_personal() {
  check_no_args "$@"
  [[ "$(hostname)" == "${PERSONAL_DESKTOP_HOSTNAME}" || "$(hostname)" == "${PERSONAL_LAPTOP_HOSTNAME}" ]]
}

function is_work() {
  check_no_args "$@"
  [[ "$(hostname)" == "${WORK_LAPTOP_HOSTNAME}" ]]
}

function is_desktop() {
  check_no_args "$@"
  [[ "$(hostname)" == "${PERSONAL_DESKTOP_HOSTNAME}" ]]
}

function is_laptop() {
  check_no_args "$@"
  [[ "$(hostname)" == "${PERSONAL_LAPTOP_HOSTNAME}" || "$(hostname)" == "${WORK_LAPTOP_HOSTNAME}" ]]
}

function is_server() {
  check_no_args "$@"
  [[ "$(hostname)" != "${PERSONAL_DESKTOP_HOSTNAME}" && "$(hostname)" != "${PERSONAL_LAPTOP_HOSTNAME}" && "$(hostname)" != "${WORK_LAPTOP_HOSTNAME}" ]]
}

# wrapper around curl to disable reading the config that is intended for interactive use
function curl_wrapper() {
  curl --disable --fail --silent --location --show-error "$@"
}

# wrapper around wget to disable reading the config that is intended for interactive use
function wget_wrapper() {
  wget --no-config "$@"
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

#shellcheck disable=SC2120
function local_ip() {
  check_no_args "$@"
  ip -oneline route get to '8.8.8.8' | sed --quiet 's/.*src \([0-9.]\+\).*/\1/p'
}

function local_network() {
  check_no_args "$@"
  local ip_num
  ip_num="$(ipv4_to_num "$(local_ip)")"
  if [[ $(ipv4_to_num '10.0.0.0') -le "${ip_num}" && "${ip_num}" -le $(ipv4_to_num '10.255.255.255') ]]; then
    echo '10.0.0.0/8'
  elif [[ $(ipv4_to_num '172.16.0.0') -le "${ip_num}" && "${ip_num}" -le $(ipv4_to_num '172.31.255.255') ]]; then
    echo '172.16.0.0/12'
  elif [[ $(ipv4_to_num '192.168.0.0') -le "${ip_num}" && "${ip_num}" -le $(ipv4_to_num '192.168.255.255') ]]; then
    echo '192.168.0.0/16'
  else
    die "Could not determine local network IPv4 range"
  fi
}

# path_remove "$(this_script_dir)"
function this_script_dir() {
  check_no_args "$@"
  cd -- "$(dirname -- "${BASH_SOURCE[1]}")" &> /dev/null && pwd
}
