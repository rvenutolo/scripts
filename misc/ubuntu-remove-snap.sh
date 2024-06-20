#!/usr/bin/env bash

# $ sudo bash -c "$(wget -qO- 'https://raw.githubusercontent.com/rvenutolo/scripts/main/misc/ubuntu-remove-snap.sh')"
# $ sudo bash -c "$(curl -fsLS 'https://raw.githubusercontent.com/rvenutolo/scripts/main/misc/ubuntu-remove-snap.sh')"

set -euo pipefail

function log() {
  echo -e "log [$(date +%T)]: $*" >&2
}

function die() {
  echo -e "DIE: $* (at ${BASH_SOURCE[1]}:${FUNCNAME[1]} line ${BASH_LINENO[0]}.)" >&2
  exit 1
}

if [[ "${EUID}" != 0 ]]; then
  die "You need to run this script with root privileges"
fi

# $1 = question
function prompt_yn() {
  REPLY=''
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

# $1 = executable
function executable_exists() {
  # executables / no builtins, aliases, or functions
  type -aPf "$1" > '/dev/null' 2>&1
}

log 'Removing snaps'
while [[ "$(snap list 2> '/dev/null' | wc --lines)" -gt 0 ]]; do
  for snap in $(snap list | tail -n '+2' | cut --delimiter=' ' --fields='1'); do
    if snap remove --purge "${snap}" &> '/dev/null'; then
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
{
  echo 'Package: snapd'
  echo 'Pin: release a=*'
  echo 'Pin-Priority: -10'
} | tee '/etc/apt/preferences.d/disable-snap.pref' > '/dev/null'

log 'Updating apt package index'
sudo apt update
log 'Updated apt package index'

existing_mounts="$(grep --invert '^\s*#' '/etc/fstab' | awk '{ print $2 }')"
readonly existing_mounts

for dir in '/snap' '/var/snap' '/var/lib/snapd' '/var/cache/snapd' '/root/snap'; do
  if [[ -d "${dir}" ]]; then
    if grep --quiet --fixed-strings --line-regexp "${dir}" <<< "${existing_mounts}"; then
      # if this dir exists in fstab, it is likely because I have a btrfs subvolume mounted at that dir
      log "Removing all files in: ${dir}"
      rm -rf "${dir:?}/"*
      log "Removed all files in: ${dir}"
    else
      log "Removing: ${dir}"
      rm -rf "${dir}"
      log "Removed: ${dir}"
    fi
  fi
done

for dir in "/home/"*; do
  if [[ -d "${dir}/snap" ]]; then
    if grep --quiet --fixed-strings --line-regexp "${dir}" <<< "${existing_mounts}"; then
      # if this dir exists in fstab, it is likely because I have a btrfs subvolume mounted at that dir
      log "Removing all files in: ${dir}/snap"
      rm -rf "${dir}/snap/"*
      log "Removed all files in: ${dir}/snap"
    else
      log "Removing: ${dir}/snap"
      rm -rf "${dir}/snap"
      log "Removed: ${dir}/snap"
    fi
  fi
done
