#!/usr/bin/env bash

# @description Remove all installed snaps, disable and mask the snapd service, uninstall the snapd package, and clean up snap directories. Must be run as root.
# @noargs

# $ sudo bash -c "$(wget -qO- 'https://raw.githubusercontent.com/rvenutolo/scripts/main/scripts/misc/ubuntu-remove-snap.sh')"
# $ sudo bash -c "$(curl -fsLS 'https://raw.githubusercontent.com/rvenutolo/scripts/main/scripts/misc/ubuntu-remove-snap.sh')"

set -Eeuo pipefail
IFS=$'\n\t'
trap 'printf "\033[0;31m[%s %s] ERROR: line %s (exit %s): %s\033[0m\n" "$(date +%T)" "${0##*/}" "${LINENO}" "$?" "${BASH_COMMAND}" >&2' ERR

if ((BASH_VERSINFO[0] < 4)); then
  printf 'bash 4+ required\n' >&2
  exit 1
fi

# @description Print a timestamped info message to stderr.
# @arg $@ message Message text to log.
function log() {
  printf 'log [%s]: %s\n' "$(date +%T)" "$*" >&2
}

# @description Print a fatal error message with caller context and exit with status 1.
# @arg $@ message Error message text.
# @exitcode 1 Always exits with status 1.
function die() {
  printf 'DIE: %s (at %s:%s line %s.)\n' "$*" "${BASH_SOURCE[1]}" "${FUNCNAME[1]}" "${BASH_LINENO[0]}" >&2
  exit 1
}

# @description Prompt the user with a yes/no question and return 0 for yes, 1 for no.
# @arg $1 question The yes/no question to display.
# @exitcode 0 User answered yes.
# @exitcode 1 User answered no.
function prompt_yn() {
  REPLY=''
  while [[ ${REPLY} != 'y' && ${REPLY} != 'n' ]]; do
    read -rp "$1 [Y/n]: "
    if [[ ${REPLY} == '' || ${REPLY} == [yY] ]]; then
      REPLY='y'
    elif [[ ${REPLY} == [nN] ]]; then
      REPLY='n'
    fi
  done
  [[ ${REPLY} == 'y' ]]
}

# @description Return true if the named executable exists on PATH (excluding builtins, aliases, and functions).
# @arg $1 executable Name of the executable to check.
# @exitcode 0 Executable found.
# @exitcode 1 Executable not found.
function executable_exists() {
  # executables / no builtins, aliases, or functions
  type -aPf "$1" >'/dev/null' 2>&1
}

function main() {
  if [[ ${EUID} != 0 ]]; then
    die "You need to run this script with root privileges"
  fi

  log 'Removing snaps'
  local snap_list_tmp
  snap_list_tmp="$(mktemp)"
  while [[ "$(snap list 2>'/dev/null' | tail --lines='+2' | wc --lines)" -gt 0 ]]; do
    snap list | tail --lines='+2' | cut --delimiter=' ' --fields=1 >"${snap_list_tmp}"
    mapfile -t snaps <"${snap_list_tmp}"
    for snap in "${snaps[@]}"; do
      if snap remove --purge "${snap}" &>'/dev/null'; then
        log "Removed snap: ${snap}"
      fi
    done
  done
  log 'Removed snaps'

  log 'Disabling snapd services'
  systemctl disable --now 'snapd.service'
  systemctl disable --now 'snapd.socket'
  systemctl disable --now 'snapd.seeded.service'
  log 'Disabled snapd services'

  log 'Masking snapd'
  systemctl mask 'snapd'
  log 'Masked snapd'

  log 'Removing snapd package'
  apt remove --autoremove --yes 'snapd'
  log 'Removed snapd package'

  log 'Writing /etc/apt/preferences.d/disable-snap.pref'
  printf '%s\n' \
    'Package: snapd' \
    'Pin: release a=*' \
    'Pin-Priority: -10' |
    tee '/etc/apt/preferences.d/disable-snap.pref' >'/dev/null'

  log 'Updating apt package index'
  sudo apt update
  log 'Updated apt package index'

  local existing_mounts
  existing_mounts="$(grep --invert '^\s*#' '/etc/fstab' | awk '{ print $2 }')"

  for dir in '/snap' '/var/snap' '/var/lib/snapd' '/var/cache/snapd' '/root/snap'; do
    if [[ -d ${dir} ]]; then
      if grep --quiet --fixed-strings --line-regexp "${dir}" <<<"${existing_mounts}"; then
        # if this dir exists in fstab, it is likely because I have a btrfs subvolume mounted at that dir
        log "Removing all files in: ${dir}"
        rm --recursive --force -- "${dir:?}/"*
        log "Removed all files in: ${dir}"
      else
        log "Removing: ${dir}"
        rm --recursive --force -- "${dir}"
        log "Removed: ${dir}"
      fi
    fi
  done

  for dir in "/home/"*; do
    if [[ -d "${dir}/snap" ]]; then
      if grep --quiet --fixed-strings --line-regexp "${dir}" <<<"${existing_mounts}"; then
        # if this dir exists in fstab, it is likely because I have a btrfs subvolume mounted at that dir
        log "Removing all files in: ${dir}/snap"
        rm --recursive --force -- "${dir}/snap/"*
        log "Removed all files in: ${dir}/snap"
      else
        log "Removing: ${dir}/snap"
        rm --recursive --force -- "${dir}/snap"
        log "Removed: ${dir}/snap"
      fi
    fi
  done
}

main "$@"
