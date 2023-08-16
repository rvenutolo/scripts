#!/usr/bin/env bash

# $ bash -c "$(wget -qO- 'https://raw.githubusercontent.com/rvenutolo/scripts/main/misc/set-up-linode-ubuntu-user.sh')"
# $ bash -c "$(curl -fsLS 'https://raw.githubusercontent.com/rvenutolo/scripts/main/misc/set-up-linode-ubuntu-user.sh')"

set -euo pipefail

function log() {
  echo -e "log [$(date +%T)]: $*" >&2
}

function die() {
  echo -e "DIE: $* (at ${BASH_SOURCE[1]}:${FUNCNAME[1]} line ${BASH_LINENO[0]}.)" >&2
  exit 1
}

# $1 = URL
# $2 = output file (optional)
function dl() {
  log "Downloading: $1"
  if [[ -n "${2:-}" ]]; then
    tries=0
    until curl --disable --fail --silent --location --show-error "$1" --output "$2"; do
      ((tries += 1))
      if ((tries > 10)); then
        die "Failed to get in 10 tries: $1"
      fi
      sleep 15
    done
  else
    tries=0
    until curl --disable --fail --silent --location --show-error "$1"; do
      ((tries += 1))
      if ((tries > 10)); then
        die "Failed to get in 10 tries: $1"
      fi
      sleep 15
    done
  fi
}

if [[ "${EUID}" == 0 ]]; then
  die "Do not run this script as root"
fi

sudo --validate

sudo apt-get update

if ! sudo apt-get --just-print dist-upgrade | grep --quiet '^0 upgraded'; then
  sudo touch '/var/run/reboot-required'
  die "Update/upgrade packages and reboot before running this script: sudo apt-get dist-upgrade --yes && sudo reboot"
fi
if [[ -f '/var/run/reboot-required' ]]; then
  die "Reboot before running this script"
fi

log 'Setting sudo timeout'
echo 'Defaults timestamp_timeout=60' | sudo tee '/etc/sudoers.d/timestamp_timeout' > /dev/null

log 'Setting hostname'
sudo hostnamectl set-hostname 'alpha'

if [[ ! -f '/tmp/dl-chezmoi.sh' ]]; then
  log 'Downloading chezmoi'
  dl 'get.chezmoi.io' '/tmp/dl-chezmoi.sh'
fi
if [[ ! -f '/tmp/chezmoi' ]]; then
  log 'Installing chezmoi'
  sh '/tmp/dl-chezmoi.sh' -b '/tmp'
fi
if [[ ! -f "${HOME}/.config/bash/rc.bash" ]]; then
  log 'Initializing chezmoi'
  /tmp/chezmoi init --apply 'rvenutolo'
fi

#shellcheck disable=SC1091
source "${HOME}/.profile"

log 'Adding Docker to package sources'
# https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
sudo install --mode='0755' --directory '/etc/apt/keyrings'
curl --disable --fail --silent --location --show-error 'https://download.docker.com/linux/ubuntu/gpg' | sudo gpg --dearmor -o '/etc/apt/keyrings/docker.gpg'
sudo chmod a+r '/etc/apt/keyrings/docker.gpg'
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(source '/etc/os-release' && echo "${VERSION_CODENAME}")" stable" | \
  sudo tee '/etc/apt/sources.list.d/docker.list' > /dev/null

log 'Installing apt packages'
sudo apt-get update
sudo apt-get install --yes \
  age \
  ca-certificates \
  curl \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
  fail2ban \
  git \
  gnupg \
  nala \
  nano \
  micro \
  openssh-client openssh-server \
  plocate \
  ufw \
  unzip \
  wget

for script in "${SCRIPTS_DIR}/packages/"*; do
  log "Running: ${script}"
  SCRIPTS_AUTO_ANSWER='y' "$script"
done

## shellcheck disable=1091
#source "${HOME}/.nix-profile/etc/profile.d/nix.sh"

#log 'Running setup scripts'
#SCRIPTS_AUTO_ANSWER='y' "${SCRIPTS_DIR}/setup/run-setup-scripts"

log 'Done'
