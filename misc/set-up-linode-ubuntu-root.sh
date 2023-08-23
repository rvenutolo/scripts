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

log 'Setting timezone'
timedatectl set-timezone 'America/New_York'

log 'Setting hostname'
hostnamectl set-hostname 'alpha'

log 'Adding Docker key and repository'
# https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
install --mode='0755' --directory '/etc/apt/keyrings'
curl --disable --fail --silent --location --show-error 'https://download.docker.com/linux/ubuntu/gpg' | gpg --dearmor -o '/etc/apt/keyrings/docker.gpg'
chmod 644 '/etc/apt/keyrings/docker.gpg'
# shellcheck disable=SC1091
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release --codename --short) stable" | tee '/etc/apt/sources.list.d/docker.list' > /dev/null

log 'Adding Tailscale key and repository'
# https://tailscale.com/download/linux/ubuntu-2204
install --mode='0755' --directory '/usr/share/keyrings'
curl --disable --fail --silent --location --show-error 'https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg' | tee '/usr/share/keyrings/tailscale-archive-keyring.gpg' > /dev/null
chmod 644 '/usr/share/keyrings/tailscale-archive-keyring.gpg'
curl --disable --fail --silent --location --show-error 'https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list' | tee '/etc/apt/sources.list.d/tailscale.list' > /dev/null
chmod 644 '/etc/apt/sources.list.d/tailscale.list'

log 'Installing apt packages'
apt-get update
apt-get install --yes \
  age \
  apt-transport-https \
  ca-certificates \
  curl \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose docker-compose-plugin \
  fail2ban \
  git \
  gnupg gnupg-agent \
  nala \
  nano \
  micro \
  openssh-client openssh-server \
  plocate \
  software-properties-common \
  tailscale \
  ufw \
  wget \
  zip unzip

log 'Running apt dist-upgrade'
apt-get dist-upgrade --yes

if ! id --user 'rvenutolo' > /dev/null 2>&1; then
  log 'Creating rvenutolo'
  useradd --create-home --shell '/usr/bin/bash' --groups 'sudo,docker' --comment 'Rick Venutolo' 'rvenutolo'
  until passwd 'rvenutolo'; do :; done
fi

log 'Done - Reboot, if necessary'
