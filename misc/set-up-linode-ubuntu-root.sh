#!/usr/bin/env bash

# $ bash -c "$(wget -qO- 'https://raw.githubusercontent.com/rvenutolo/scripts/main/misc/set-up-linode-ubuntu-root.sh')"
# $ bash -c "$(curl -fsLS 'https://raw.githubusercontent.com/rvenutolo/scripts/main/misc/set-up-linode-ubuntu-root.sh')"

set -euo pipefail

function log() {
  echo -e "log [$(date +%T)]: $*" >&2
}

function die() {
  echo -e "DIE: $* (at ${BASH_SOURCE[1]}:${FUNCNAME[1]} line ${BASH_LINENO[0]}.)" >&2
  exit 1
}

if [[ "${EUID}" != 0 ]]; then
  die "Run this script as root"
fi

if ! id --user 'rvenutolo' > /dev/null 2>&1; then
  useradd --create-home --groups 'adm,sudo' --comment 'Rick Venutolo' 'rvenutolo'
  until passwd 'rvenutolo'; do :; done
fi

log 'Updating packages'
apt-get update
apt-get dist-upgrade --yes

log 'Done -- Rebooting'
reboot
