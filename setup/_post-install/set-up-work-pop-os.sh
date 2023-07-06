#!/usr/bin/env bash

# $ bash -c "$(wget -qO- 'https://raw.githubusercontent.com/rvenutolo/scripts/main/setup/_post-install/set-up-work-pop-os.sh')"
# $ bash -c "$(curl -fsLS 'https://raw.githubusercontent.com/rvenutolo/scripts/main/setup/_post-install/set-up-work-pop-os.sh')"

set -euo pipefail

readonly nixpkgs_url='https://raw.githubusercontent.com/rvenutolo/packages/main/nixpkgs.csv'
readonly flatpaks_url='https://raw.githubusercontent.com/rvenutolo/packages/main/flatpaks.csv'
readonly sdkman_url='https://raw.githubusercontent.com/rvenutolo/packages/main/sdkman.csv'
readonly nerd_fonts_url='https://raw.githubusercontent.com/rvenutolo/packages/main/nerd_fonts.csv'

function log() {
  echo -e "log [$(date +%T)]: $*" >&2
}

function die() {
  echo -e "DIE: $* (at ${BASH_SOURCE[1]}:${FUNCNAME[1]} line ${BASH_LINENO[0]}.)" >&2
  exit 1
}

# $1 = executable
function executable_exists() {
  # executables / no builtins, aliases, or functions
  type -aPf "$1" > /dev/null 2>&1
}

# $1 = url
function get_pkgs() {
  curl -fsLS "$1" | awk -F',' '$5 == "y" && $7 == "" { print $2 }'
}

function get_sdkman_pkgs() {
  curl -fsLS "${sdkman_url}" | tail --lines='+2' | cut --delimiter=',' --fields='2'
}

function get_fonts() {
  curl -fsLS "${nerd_fonts_url}" | tail --lines='+2' | cut --delimiter=',' --fields='2'
}

if [[ "${EUID}" == 0 ]]; then
  die "Do not run this script as root"
fi

sudo --validate

log 'Setting hostname'
hostnamectl set-hostname 'silverstar'

if ! dpkg --status 'libssl1.1' > /dev/null 2>&1; then
  log 'Installing old libssl1.1 package for AWS VPN client'
  libssl1_url='http://security.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.19_amd64.deb'
  libssl1_deb="$(mktemp --suffix "__$(basename "${libssl1_url}")")"
  curl -fsLSo "${libssl1_deb}" "${libssl1_url}"
  sudo apt-get install "${libssl1_deb}"
fi

if [[ ! -f '/etc/apt/trusted.gpg.d/awsvpnclient_public_key.asc' ]]; then
  curl -fsLS 'https://d20adtppz83p9s.cloudfront.net/GTK/latest/debian-repo/awsvpnclient_public_key.asc' | sudo tee '/etc/apt/trusted.gpg.d/awsvpnclient_public_key.asc' > '/dev/null'
fi
if [[ ! -f '/etc/apt/sources.list.d/aws-vpn-client.list' ]]; then
  echo 'deb [arch=amd64] https://d20adtppz83p9s.cloudfront.net/GTK/latest/debian-repo ubuntu-20.04 main' | sudo tee '/etc/apt/sources.list.d/aws-vpn-client.list' > '/dev/null'
fi

log 'Removing apt packages'
sudo apt-get remove --yes geary firefox libreoffice-*
sudo apt-get autoremove --yes

log 'Updating apt package list'
sudo apt-get update

log 'Upgrading existing apt packages'
sudo apt-get dist-upgrade --yes
sudo apt-get autoremove --yes

log 'Installing apt packages'
sudo apt-get install --yes \
  alacritty \
  awsvpnclient \
  bridge-utils \
  cpu-checker \
  flatpak \
  gnome-software-plugin-flatpak gnome-tweaks \
  gparted \
  kitty \
  krusader \
  libvirt-daemon libvirt-daemon-system libvirt-clients \
  nala \
  ovmf \
  qemu qemu-kvm qemu-utils \
  virtinst

if ! systemctl is-enabled --quiet 'libvirtd'; then
  sudo systemctl enable --now 'libvirtd'
fi

if [[ ! -f "${HOME}/.nix-profile/etc/profile.d/nix.sh" ]]; then
  log 'Installing nix package manager'
  if [[ ! -d '/nix' ]]; then
    sudo mkdir '/nix'
  fi
  sudo chmod 755 '/nix'
  sudo chown --recursive "${USER}:" '/nix'
  sh <(curl -fsLS 'https://nixos.org/nix/install') --no-daemon
fi

## TODO check on GUI packages - look for .desktop files
# ls -1 ~/.nix-profile/share/applications/
# ~/.nix-profile/share/applications/*.desktop | grep -F 'Exec='
log 'Installing Nix packages'
# shellcheck disable=SC1091
source "${HOME}/.nix-profile/etc/profile.d/nix.sh"
export NIXPKGS_ALLOW_UNFREE='1'
get_pkgs "${nixpkgs_url}" | xargs printf -- 'nixpkgs.%s\n' | xargs nix-env --install --attr

log 'Installing flatpaks'
flatpak remote-add --user --if-not-exists 'flathub' 'https://dl.flathub.org/repo/flathub.flatpakrepo'
get_pkgs "${flatpaks_url}" | xargs flatpak install --or-update --user --noninteractive

if [[ ! -f "${HOME}/.sdkman/bin/sdkman-init.sh" ]]; then
  log 'Installing SDKMAN'
  bash <(curl -fsLS 'https://get.sdkman.io?rcupdate=false')
fi

log 'Installing SDKMAN packages'
sed --in-place 's/sdkman_auto_answer=false/sdkman_auto_answer=true/g' "${HOME}/.sdkman/etc/config"
set +u
# shellcheck disable=SC1091
source "${HOME}/.sdkman/bin/sdkman-init.sh"
get_sdkman_pkgs | while read -r pkg; do
  if [[ "${pkg}" == 'java' ]]; then
    sdk list java | grep --fixed-strings '|' | cut --delimiter='|' --fields='6' | grep '\-tem\s*$' | tac | while read -r jdk; do
      # retry due to random timeouts
      tries=0
      until sdk install java "${jdk}"; do
        ((tries += 1))
        if ((${tries} > 10)); then
          die "Failed to download in 10 tries: ${jdk}"
        fi
        sleep 15
      done
    done
  else
    # retry due to random timeouts
    tries=0
    until sdk install "${pkg}"; do
      ((tries += 1))
      if ((${tries} > 10)); then
        die "Failed to download in 10 tries: ${pkg}"
      fi
      sleep 15
    done
  fi
done
set -u
sed --in-place 's/sdkman_auto_answer=true/sdkman_auto_answer=false/g' "${HOME}/.sdkman/etc/config"

## TODO can I use nixpkgs instead?
log 'Installing Nerd Fonts'
fonts_dir="${HOME}/.local/share/fonts"
if [[ ! -d "${fonts_dir}" ]]; then
  mkdir --parents "${fonts_dir}"
fi
nerd_fonts_version="$(curl -fsLS https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | jq --raw-output '.tag_name')"
get_fonts | while read -r font; do
  archive_file="${font}.tar.xz"
  output_file="$(mktemp --suffix "_${archive_file}")"
  tries=0
  until curl -fsLSo "${output_file}" "https://github.com/ryanoasis/nerd-fonts/releases/download/${nerd_fonts_version}/${archive_file}"; do
    ((tries += 1))
    if ((${tries} > 10)); then
      die "Failed to download in 10 tries: ${font}"
    fi
    sleep 15
  done
  tar --extract --file="${output_file}" --directory="${fonts_dir}" --wildcards '*.[ot]tf'
done
find "${fonts_dir}" -name '*Windows Compatible*' -delete
fc-cache --force

# shellcheck disable=SC2016
log 'Finished\nYou may want to run the following:\nsource ${HOME}/.nix-profile/etc/profile.d/nix.sh\nsource ${HOME}/.sdkman/bin/sdkman-init.sh\nchezmoi init --apply rvenutolo'
