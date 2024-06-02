#!/usr/bin/env bash

#source "${SCRIPTS_DIR}/functions.bash"

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
  (
    ## remove from path so scripts that mask commands are no longer on PATH, ex: mvn
    ## do this in a subshell to not mess up PATH in parent shell
    path_remove "${SCRIPTS_DIR}/main"
    path_remove "${SCRIPTS_DIR}/other"
    # executables / no builtins, aliases, or functions
    type -aPf "$1" > /dev/null 2>&1
  )
}

# $1 = function
function function_exists() {
  check_exactly_1_arg "$@"
  declare -f "$1" > /dev/null 2>&1
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

# $1 = env
function is_desktop_env() {
  check_exactly_1_arg "$@"
  echo "${XDG_CURRENT_DESKTOP:-}" | contains_word "$1"
}

function is_kde() {
  check_no_args "$@"
  [[ "${XDG_CURRENT_DESKTOP:-}" == 'KDE' ]]
}

function is_gnome() {
  check_no_args "$@"
  [[ "${XDG_CURRENT_DESKTOP:-}" == 'GNOME' ]] || [[ "${XDG_CURRENT_DESKTOP:-}" == 'ubuntu:GNOME' ]]
}

function is_pop_shell() {
  check_no_args "$@"
  [[ "${XDG_CURRENT_DESKTOP:-}" == 'pop:GNOME' ]]
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

function auto_answer() {
  [[ -n "${SCRIPTS_AUTO_ANSWER:-}" ]]
}

# $1 = question
function prompt_ny() {
  check_exactly_1_arg "$@"
  REPLY=''
  if auto_answer; then
    REPLY='n'
  fi
  while [[ "${REPLY}" != 'y' && "${REPLY}" != 'n' ]]; do
    read -rp "$1 [y/N]: "
    if [[ "${REPLY}" == [yY] ]]; then
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
  if auto_answer; then
    REPLY='y'
  fi
  while [[ "${REPLY}" != 'y' && "${REPLY}" != 'n' ]]; do
    read -rp "$1 [Y/n]: "
    if [[ "${REPLY}" == '' || "${REPLY}" == [yY] ]]; then
      REPLY='y'
    elif [[ "${REPLY}" == [nN] ]]; then
      REPLY='n'
    fi
  done
  [[ "${REPLY}" == 'y' ]]
}

# $1 = question
# $2 = default value (optional)
function prompt_for_value() {
  check_at_least_1_arg "$@"
  check_at_most_2_args "$@"
  if [[ -n "${2:-}" ]]; then
    REPLY=''
    if auto_answer; then
      REPLY="$2"
    fi
    if [[ "${REPLY}" == '' ]]; then
      read -rp "$1 [$2]: "
      if [[ "${REPLY}" == '' ]]; then
        REPLY="$2"
      fi
    fi
    echo "${REPLY}"
  else
    REPLY=''
    while [[ -z "${REPLY}" ]]; do
      read -rp "$1: "
    done
    echo "${REPLY}"
  fi
}

# $1 = target file
# $2 = link file
function link_user_file() {
  check_not_root
  check_exactly_2_args "$@"
  if [[ ! -f "$1" ]]; then
    die "$1 does not exist"
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
  mkdir --parents "$(dirname "$2")"
  ln --symbolic --force "$1" "$2"
  log "Linked: $1 -> $2"
}

# $1 = old file location
# $2 = new file location
function move_user_file() {
  check_not_root
  check_exactly_2_args "$@"
  if [[ ! -f "$1" ]]; then
    die "$1 does not exist"
  fi
  if [[ "$1" == "$2" ]]; then
    die "File paths are the same"
  fi
  if [[ -f "$2" ]]; then
    diff --color --unified "$2" "$1" || true
    if ! prompt_yn "$2 exists - Overwrite: $1 -> $2?"; then
      exit 0
    fi
  else
    if ! prompt_yn "Move $1 -> $2?"; then
      exit 0
    fi
  fi
  log "Moving: $1 -> $2"
  mkdir --parents "$(dirname "$2")"
  mv "$1" "$2"
  log "Moved: $1 -> $2"
}

# $1 = old file location
# $2 = new file location
function copy_user_file() {
  check_not_root
  check_exactly_2_args "$@"
  if [[ ! -f "$1" ]]; then
    die "$1 does not exist"
  fi
  if [[ "$1" == "$2" ]]; then
    die "File paths are the same"
  fi
  if [[ -f "$2" ]]; then
    if cmp --silent "$1" "$2"; then
      exit 0
    else
      diff --color --unified "$2" "$1" || true
      if ! prompt_yn "$2 exists - Overwrite: $1 -> $2?"; then
        exit 0
      fi
    fi
  else
    if ! prompt_yn "Copy $1 -> $2?"; then
      exit 0
    fi
  fi
  log "Copying: $1 -> $2"
  mkdir --parents "$(dirname "$2")"
  cp "$1" "$2"
  log "Copied: $1 -> $2"
}

# $1 = source file
# $2 = destination file
function copy_system_file() {
  check_exactly_2_args "$@"
  if [[ ! -f "$1" ]]; then
    die "$1 does not exist"
  fi
  if [[ "$1" == "$2" ]]; then
    die "File paths are the same"
  fi
  if [[ -f "$2" ]]; then
    if cmp --silent "$1" "$2"; then
      exit 0
    else
      diff --color --unified "$2" "$1" || true
      if ! prompt_yn "$2 exists - Overwrite: $1 -> $2?"; then
        exit 0
      fi
    fi
  else
    if ! prompt_yn "Copy $1 -> $2?"; then
      exit 0
    fi
  fi
  log "Copying: $1 -> $2"
  sudo mkdir --parents "$(dirname "$2")"
  sudo cp "$1" "$2"
  log "Copied: $1 -> $2"
}

# $1 = service unit file
function user_service_unit_file_exists() {
  systemctl --user list-unit-files --all --quiet "$1" > /dev/null
}

# $1 = service unit file
function enable_user_service_unit() {
  check_not_root
  check_exactly_1_arg "$@"
  if user_service_unit_file_exists "$1"; then
    if ! systemctl is-enabled --user --quiet "$1" && prompt_yn "Enable and start $1 user service?"; then
      log "Enabling and starting $1 user service"
      systemctl enable --now --user --quiet "$1"
      log "Enabled and started $1 user service"
    fi
  else
    log "User service unit files does not exist: $1"
  fi
}

# $1 = service unit file
function restart_user_service_if_enabled() {
  check_not_root
  check_exactly_1_arg "$@"
  if user_service_unit_file_exists "$1"; then
    if systemctl is-enabled --user --quiet "$1" && prompt_yn "Restart $1 user service?"; then
      log "Restarting $1 user service"
      systemctl restart --user --quiet "$1"
      log "Restarted $1 user service"
    fi
  else
    log "User service unit files does not exist: $1"
  fi
}

# $1 = service unit file
function system_service_unit_file_exists() {
  systemctl --system list-unit-files --all --quiet "$1" > /dev/null
}

# $1 = service unit file
function enable_system_service_unit() {
  check_exactly_1_arg "$@"
  if system_service_unit_file_exists "$1"; then
    if ! systemctl is-enabled --system --quiet "$1" && prompt_yn "Enable and start $1 system service?"; then
      log "Enabling and starting $1 system service"
      sudo systemctl enable --now --system --quiet "$1"
      log "Enabled and started $1 system service"
    fi
  else
    log "System service unit files does not exist: $1"
  fi
}

# $1 = service unit file
function restart_system_service_if_enabled() {
  check_exactly_1_arg "$@"
  if system_service_unit_file_exists "$1"; then
    if systemctl is-enabled --system --quiet "$1" && prompt_yn "Restart $1 system service?"; then
      log "Restarting $1 system service"
      sudo systemctl restart --system --quiet "$1"
      log "Restarted $1 system service"
    fi
  else
    log "System service unit files does not exist: $1"
  fi
}

function reload_sysctl_conf() {
  check_no_args "$@"
  if prompt_yn 'Reload sysctl configuration?'; then
    log 'Reloading sysctl configuration'
    sudo sysctl --system --quiet
    log 'Reloaded sysctl configuration'
  fi
}

# $1 = packages list type (flatpaks nixpkgs sdkman)
function get_universal_packages() {
  check_exactly_1_arg "$@"
  case "$1" in
    appimages | flatpaks | nixpkgs | sdkman) : ;;
    *) die "Unexpected package list type: $1" ;;
  esac
  local package_list_url="https://raw.githubusercontent.com/rvenutolo/packages/main/$1.csv"
  if is_personal && is_desktop; then
    local package_list_column=3
  elif is_personal && is_laptop; then
    local package_list_column=4
  elif is_work && is_laptop; then
    local package_list_column=5
  elif is_server; then
    local package_list_column=6
  else
    die "Could not determine which computer this is"
  fi
  download "${package_list_url}" | awk -F ',' -v "col_num=${package_list_column}" '$col_num == "y" && $7 == "" { print $2 }'
}

# $1 = id
# $2 = codename
function get_distro_packages() {
  check_exactly_2_args "$@"
  local package_list_url="https://raw.githubusercontent.com/rvenutolo/packages/main/$1-$2.csv"
  if ! curl_wrapper --output '/dev/null' --head "${package_list_url}"; then
    die "No packages list for $1 $2"
  fi
  if is_personal && is_desktop; then
    local package_list_column=2
  elif is_personal && is_laptop; then
    local package_list_column=3
  elif is_work && is_laptop; then
    local package_list_column=4
  elif is_server; then
    local package_list_column=5
  else
    die "Could not determine which computer this is"
  fi
  download "${package_list_url}" | awk -F ',' -v "col_num=${package_list_column}" '$col_num == "y" && $6 == "" { print $1 }'
}

function get_install_scripts() {
  check_no_args
  local package_list_url="https://raw.githubusercontent.com/rvenutolo/packages/main/scripts.csv"
  if is_personal && is_desktop; then
    local package_list_column=4
  elif is_personal && is_laptop; then
    local package_list_column=5
  elif is_work && is_laptop; then
    local package_list_column=6
  elif is_server; then
    local package_list_column=7
  else
    die "Could not determine which computer this is"
  fi
  download "${package_list_url}" | awk -F ',' -v "col_num=${package_list_column}" '$col_num == "y" && $8 == "" { print $1, $2, $3 }'
}
