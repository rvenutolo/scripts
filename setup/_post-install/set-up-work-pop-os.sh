#!/usr/bin/env bash

# $ bash -c "$(wget -qO- 'https://raw.githubusercontent.com/rvenutolo/scripts/main/setup/_post-install/set-up-work-pop-os.sh')"
# $ bash -c "$(curl -fsLS 'https://raw.githubusercontent.com/rvenutolo/scripts/main/setup/_post-install/set-up-work-pop-os.sh')"

set -euo pipefail

readonly nixpkgs_url='https://raw.githubusercontent.com/rvenutolo/packages/main/nixpkgs.csv'
readonly flatpaks_url='https://raw.githubusercontent.com/rvenutolo/packages/main/flatpaks.csv'
readonly sdkman_url='https://raw.githubusercontent.com/rvenutolo/packages/main/sdkman.csv'
readonly nerd_fonts_url='https://raw.githubusercontent.com/rvenutolo/packages/main/nerd_fonts.csv'

# $1 = URL
# $2 = output file (optional)
function dl() {
  log "Downloading: $1"
  if [[ -n "${2:-}" ]]; then
    tries=0
    until curl --fail --silent --location --show-error "$1" --output "$2"; do
      ((tries += 1))
      if ((${tries} > 10)); then
        die "Failed to get in 10 tries: ${url}"
      fi
      sleep 15
    done
  else
    tries=0
    until curl --fail --silent --location --show-error "$1"; do
      ((tries += 1))
      if ((${tries} > 10)); then
        die "Failed to get in 10 tries: ${url}"
      fi
      sleep 15
    done
  fi
}

# $1 = URL
# $2 = output file (optional)
function dl_decrypt() {
  if [[ -n "${2:-}" ]]; then
    dl "$1" | age --decrypt --identity "${HOME}/.keys/age.key" --output "$2"
  else
    dl "$1" | age --decrypt --identity "${HOME}/.keys/age.key"
  fi
}

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
  dl "$1" | awk -F',' '$5 == "y" && $7 == "" { print $2 }'
}

function get_sdkman_pkgs() {
  dl "${sdkman_url}" | tail --lines='+2' | cut --delimiter=',' --fields='2'
}

function get_fonts() {
  dl "${nerd_fonts_url}" | tail --lines='+2' | cut --delimiter=',' --fields='2'
}

if [[ "${EUID}" == 0 ]]; then
  die "Do not run this script as root"
fi

sudo --validate

log 'Installing age'
sudo apt-get install age

log 'Getting keys'
if [[ ! -f "${HOME}/.keys/age.key" ]]; then
  mkdir --parents "${HOME}/.keys"
  dl 'https://raw.githubusercontent.com/rvenutolo/crypt/main/keys/age.key' | age --decrypt --output "${HOME}/.keys/age.key"
fi
keys=(
  'authorized_keys .ssh'
  'core-dev-general.pem .keys'
  'id_ed25519 .keys'
  'id_ed25519.pub .keys'
  'pihole .keys'
  'pihole.pub .keys'
)
for line in "${keys[@]}"; do
  IFS=' ' read -r file dir <<< "${line}"
  mkdir --parents "${dir}"
  dl_decrypt "https://raw.githubusercontent.com/rvenutolo/crypt/main/keys/${file}" "${HOME}/${dir}/${file}"
done

log 'Setting hostname'
hostnamectl set-hostname 'silverstar'

log 'Setting user to linger'
sudo loginctl enable-linger "${USER}"

log 'Adding to user groups'
groups=('sys' 'wheel' 'kvm' 'input' 'libvirtd')
for group in "${groups[@]}"; do
  sudo groupadd --force "${group}"
  sudo usermod --append --groups "${group}" "${USER}"
done

# skip this if running in vm for testing
if [[ ! -e '/dev/sr0' ]]; then
  log 'Updating firmware'
  sudo fwupdmgr refresh
  sudo fwupdmgr update
fi

if ! dpkg --status 'libssl1.1' > /dev/null 2>&1; then
  log 'Installing old libssl1.1 package for AWS VPN client'
  libssl1_url='http://security.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.19_amd64.deb'
  libssl1_deb="$(mktemp --suffix "__$(basename "${libssl1_url}")")"
  dl "${libssl1_url}" "${libssl1_deb}"
  sudo apt-get install "${libssl1_deb}"
fi

dl 'https://d20adtppz83p9s.cloudfront.net/GTK/latest/debian-repo/awsvpnclient_public_key.asc' | sudo tee '/etc/apt/trusted.gpg.d/awsvpnclient_public_key.asc' > '/dev/null'
echo 'deb [arch=amd64] https://d20adtppz83p9s.cloudfront.net/GTK/latest/debian-repo ubuntu-20.04 main' | sudo tee '/etc/apt/sources.list.d/aws-vpn-client.list' > '/dev/null'

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
  age \
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
  openssh-server \
  ovmf \
  qemu qemu-kvm qemu-utils \
  virtinst

sudo systemctl enable --now 'libvirtd'

## TODO vnc server

log 'Setting dconf settings'
gsettings=(
  'org.gnome.desktop.datetime automatic-timezone false'
  "org.gnome.desktop.input-sources xkb-options ['caps:super']"
  'org.gnome.desktop.interface color-scheme prefer-dark'
  'org.gnome.desktop.interface clock-show-weekday true'
  'org.gnome.desktop.interface locate-pointer true'
  'org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled true'
  'org.gnome.desktop.screensaver lock-delay uint32 30'
  'org.gnome.desktop.session idle-delay uint32 900'
  'org.gnome.desktop.wm.preferences action-middle-click-titlebar toggle-shade'
  'org.gnome.desktop.wm.preferences button-layout appmenu:minimize,maximize,close'
  'org.gnome.mutter center-new-windows true'
  'org.gnome.settings-daemon.plugins.color night-light-enabled true'
  'org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 1800'
  'org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type suspend'
  'org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 1800'
  'org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type suspend'
  'org.gnome.system.location enabled true'
)
for line in "${gsettings[@]}"; do
  IFS=' ' read -r schema key value <<< "${line}"
  gsettings set "${schema}" "${key}" "${value}"
done

if [[ ! -f "${HOME}/.nix-profile/etc/profile.d/nix.sh" ]]; then
  log 'Installing nix package manager'
  if [[ ! -d '/nix' ]]; then
    sudo mkdir '/nix'
  fi
  sudo chmod 755 '/nix'
  sudo chown --recursive "${USER}:" '/nix'
  sh <(dl 'https://nixos.org/nix/install') --no-daemon
fi

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
  bash <(dl 'https://get.sdkman.io?rcupdate=false')
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
nerd_fonts_version="$(dl https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | jq --raw-output '.tag_name')"
get_fonts | while read -r font; do
  archive_file="${font}.tar.xz"
  output_file="$(mktemp --suffix "_${archive_file}")"
  tries=0
  until dl "https://github.com/ryanoasis/nerd-fonts/releases/download/${nerd_fonts_version}/${archive_file}" "${output_file}"; do
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

log 'Getting de-400 connection file'
dl_decrypt 'https://raw.githubusercontent.com/rvenutolo/crypt/main/misc/de-400.nmconnection' '/etc/NetworkManager/system-connections/de-400.nmconnection'

# shellcheck disable=SC2016
log 'Finished\nYou may want to run the following:\nsource ${HOME}/.nix-profile/etc/profile.d/nix.sh\nsource ${HOME}/.sdkman/bin/sdkman-init.sh\nchezmoi init --apply rvenutolo'
