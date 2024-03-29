#!/usr/bin/env bash

# $ bash -c "$(wget -qO- 'https://raw.githubusercontent.com/rvenutolo/scripts/main/misc/set-up-linode-ubuntu-2204.sh')"
# $ bash -c "$(curl -fsLS 'https://raw.githubusercontent.com/rvenutolo/scripts/main/misc/set-up-linode-ubuntu-2204.sh')"

# Create user:
# useradd --create-home --shell '/usr/bin/bash' --groups 'sudo' --comment 'Rick Venutolo' 'rvenutolo'
# passwd 'rvenutolo'

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
  die "Update/upgrade packages and reboot before running this script: \nsudo apt-get dist-upgrade --yes && sudo apt-get autoremove --yes && sudo reboot"
fi
if [[ -f '/var/run/reboot-required' ]]; then
  die "Reboot before running this script"
fi

log 'Setting timezone'
sudo timedatectl set-timezone 'America/New_York'

log 'Setting hostname'
sudo hostnamectl set-hostname 'meatball'

log 'Installing apt packages'
sudo apt-get install --yes \
  age \
  apt-transport-https \
  ca-certificates \
  curl \
  fail2ban \
  git \
  gnupg gnupg-agent \
  nala \
  nano \
  micro \
  openssh-client openssh-server \
  plocate \
  software-properties-common \
  ufw \
  wget \
  zip unzip
sudo apt-get autoremove --yes

if [[ ! -f '/tmp/chezmoi' ]]; then
  log 'Installing chezmoi'
  bash -c "$(dl 'get.chezmoi.io')" -- -b '/tmp'
fi
if [[ ! -f "${HOME}/.config/bash/rc.bash" ]]; then
  log 'Initializing chezmoi'
  /tmp/chezmoi init --apply 'rvenutolo'
fi

#shellcheck disable=SC1091
source "${HOME}/.profile"

log 'Running install scripts'
SCRIPTS_AUTO_ANSWER='y' "${SCRIPTS_DIR}/run-install-scripts"

log 'Running set up scripts'
SCRIPTS_AUTO_ANSWER='y' "${SCRIPTS_DIR}/run-set-up-scripts"

#log 'Starting Portainer'
## TODO docker compose? -- https://www.youtube.com/watch?v=7oUjfsaR0NU
#docker volume create 'portainer_data'
#docker run --detach \
#  --publish '9443:9443' \
#  --publish '8000:8000' \
#  --name 'portainer' \
#  --restart='unless-stopped' \
#  --volume '/var/run/docker.sock:/var/run/docker.sock' \
#  --volume 'portainer_data:/data' \
#  'portainer/portainer-ce:latest'

## TODO joplin server

## TODO check sudo ss -atpu

log 'Done'
log 'Run: source ~/.bashrc'
