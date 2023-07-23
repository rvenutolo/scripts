#!/usr/bin/env bash

# $ bash -c "$(wget -qO- 'https://raw.githubusercontent.com/rvenutolo/scripts/main/misc/set-up-work-pop-os.sh')"
# $ bash -c "$(curl -fsLS 'https://raw.githubusercontent.com/rvenutolo/scripts/main/misc/set-up-work-pop-os.sh')"

set -euo pipefail

readonly dt_ip='172.16.0.21'

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
        die "Failed to get in 10 tries: ${url}"
      fi
      sleep 15
    done
  else
    tries=0
    until curl --disable --fail --silent --location --show-error "$1"; do
      ((tries += 1))
      if ((tries > 10)); then
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

if [[ "${EUID}" == 0 ]]; then
  die "Do not run this script as root"
fi

sudo --validate

echo 'Defaults timestamp_timeout=60' | sudo tee '/etc/sudoers.d/timestamp_timeout' > '/dev/null'

if ! dpkg --status 'libssl1.1' > /dev/null 2>&1; then
  log 'Installing old libssl1.1 package for AWS VPN client'
  libssl1_url='http://security.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.19_amd64.deb'
  libssl1_deb="$(mktemp --suffix "__$(basename "${libssl1_url}")")"
  dl "${libssl1_url}" "${libssl1_deb}"
  sudo apt-get install --yes "${libssl1_deb}"
fi

dl 'https://d20adtppz83p9s.cloudfront.net/GTK/latest/debian-repo/awsvpnclient_public_key.asc' | sudo tee '/etc/apt/trusted.gpg.d/awsvpnclient_public_key.asc' > '/dev/null'
sudo chmod 644 '/etc/apt/trusted.gpg.d/awsvpnclient_public_key.asc'
echo 'deb [arch=amd64] https://d20adtppz83p9s.cloudfront.net/GTK/latest/debian-repo ubuntu-20.04 main' | sudo tee '/etc/apt/sources.list.d/aws-vpn-client.list' > '/dev/null'
sudo chmod 644 '/etc/apt/sources.list.d/aws-vpn-client.list'

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
  caffeine \
  cpu-checker \
  dconf-editor \
  fail2ban \
  flatpak \
  git \
  gir1.2-nautilus-3.0 gir1.2-ebook-1.2 gir1.2-ebookcontacts-1.2 gir1.2-edataserver-1.2 \
  gnome-shell-extensions \
  gnome-shell-extension-gsconnect-browsers \
  gnome-software-plugin-flatpak gnome-tweaks \
  gparted \
  kitty \
  krusader \
  libfuse2 \
  libvirt-daemon libvirt-daemon-system libvirt-clients \
  nala \
  nautilus-admin \
  openssh-client openssh-server \
  ovmf \
  preload \
  python3-nautilus \
  qemu qemu-kvm qemu-utils \
  synaptic \
  virtinst

eval "$(ssh-agent)"
ssh-add "${HOME}/.keys/id_ed25519"

log 'Downloading and running chezmoi'
if [[ ! -f '/tmp/dl-chezmoi.sh' ]]; then
  dl 'get.chezmoi.io' '/tmp/dl-chezmoi.sh'
fi
if [[ ! -f '/tmp/chezmoi' ]]; then
  sh '/tmp/dl-chezmoi.sh' -b '/tmp'
fi
if [[ ! -f "${HOME}/.config/bash/rc.bash" ]]; then
  /tmp/chezmoi init --apply 'rvenutolo'
fi

source "${HOME}/.profile"

home_dir_files_to_copy=(
  '.application-deployment'
  '.bin/create-emr-test-cluster'
  '.config/AWSVPNClient'
  '.de'
  '.var/app/com.slack.Slack'
  'carbonblack'
)
for file in "${home_dir_files_to_copy[@]}"; do
  log "Copying ${HOME}/${file} from dt"
  rsync --rsh='ssh -o StrictHostKeyChecking=no' --archive --human-readable --executability --relative "${dt_ip}:${file}" "${HOME}"
done

log 'Getting de-400 connection file'
dl_decrypt 'https://raw.githubusercontent.com/rvenutolo/crypt/main/misc/de-400.nmconnection' | sudo tee '/etc/NetworkManager/system-connections/de-400.nmconnection' > '/dev/null'
sudo chmod 600 '/etc/NetworkManager/system-connections/de-400.nmconnection'

log 'Setting dconf settings'
gsettings=(
  'org.gnome.desktop.datetime automatic-timezone false'
  "org.gnome.desktop.input-sources xkb-options ['caps:super']"
  'org.gnome.desktop.interface color-scheme prefer-dark'
  'org.gnome.desktop.interface clock-show-weekday true'
  'org.gnome.desktop.interface locate-pointer true'
  'org.gnome.desktop.interface show-battery-percentage true'
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
  "org.gnome.shell disabled-extensions ['apps-menu@gnome-shell-extensions.gcampax.github.com', 'ding@rastersoft.com', 'window-list@gnome-shell-extensions.gcampax.github.com']"
  "org.gnome.shell enabled-extensions ['cosmic-dock@system76.com', 'pop-shell@system76.com', 'popx11gestures@system76.com', 'system-monitor@paradoxxx.zero.gmail.com', 'ubuntu-appindicators@ubuntu.com', 'Vitals@CoreCoding.com', 'cosmic-workspaces@system76.com', 'clipboard-indicator@tudmotu.com', 'system76-power@system76.com', 'pop-cosmic@system76.com', 'gsconnect@andyholmes.github.io', 'auto-move-windows@gnome-shell-extensions.gcampax.github.com', 'places-menu@gnome-shell-extensions.gcampax.github.com', 'drive-menu@gnome-shell-extensions.gcampax.github.com', 'workspace-indicator@gnome-shell-extensions.gcampax.github.com']"
  "org.gnome.shell favorite-apps ['pop-cosmic-launcher.desktop', 'pop-cosmic-workspaces.desktop', 'pop-cosmic-applications.desktop', 'org.gnome.Nautilus.desktop', 'org.kde.krusader.desktop', 'com.alacritty.Alacritty.desktop', 'kitty.desktop', 'com.jetbrains.IntelliJ-IDEA-Ultimate.desktop', 'com.jetbrains.DataGrip.desktop', 'io.github.shiftey.Desktop.desktop', 'com.axosoft.GitKraken.desktop', 'awsvpnclient.desktop', 'com.brave.Browser.desktop', 'com.slack.Slack.desktop', 'gnome-control-center.desktop']"
  'org.gnome.shell.extensions.dash-to-dock click-action minimize'
  'org.gnome.shell.extensions.dash-to-dock intellihide false'
  'org.gnome.shell.extensions.pop-shell active-hint true'
  'org.gnome.shell.weather automatic-location true'
  'org.gnome.system.location enabled true'
  # TODO test these - check if rdp enable has to be true for vnc to work
  'org.gnome.desktop.remote-desktop.rdp enable true'
  'org.gnome.desktop.remote-desktop.rdp view-only false'
  'org.gnome.desktop.remote-desktop.vnc auth-method password'
  'org.gnome.desktop.remote-desktop.vnc enable true'
  'org.gnome.desktop.remote-desktop.vnc view-only false'
)
for line in "${gsettings[@]}"; do
  IFS=' ' read -r schema key value <<< "${line}"
  gsettings set "${schema}" "${key}" "${value}"
done

log 'Setting hostname'
hostnamectl set-hostname 'silverstar'

"${CODE_DIR}/Personal/scripts/setup/run-setup-scripts"

# shellcheck disable=1091
source "${HOME}/.nix-profile/etc/profile.d/nix.sh"

log 'Installing GNOME extensions'
gnome_extensions=(
  'https://extensions.gnome.org/extension/779/clipboard-indicator/'
  'https://extensions.gnome.org/extension/1319/gsconnect/'
  'https://extensions.gnome.org/extension/1460/vitals/'
)
for url in "${gnome_extensions[@]}"; do
  package_num="$(cut --delimiter='/' --fields='5' <<< "${url}")"
  log "Installing extension from URL: ${url}"
  gext --filesystem install "${package_num}"
done

log 'Adding autostart applications'
mkdir --parents "${HOME}/.config/autostart"
autostart_files=(
  '/usr/share/applications/caffeine-indicator.desktop'
)
for autostart_file in "${autostart_files[@]}"; do
  if [[ -f "${autostart_file}" ]]; then
    ln --symbolic --force "${autostart_file}" "${HOME}/.config/autostart/"
  fi
done

# Skip these if running in vm for testing.
if [[ ! -e '/dev/sr0' ]]; then

  log 'Installing fingerprint scanner packages'
  sudo apt-get install --yes fprintd libpam-fprintd
  sudo pam-auth-update --enable fprintd
  if [[ ! -f '/etc/pam.d/common-auth.orig' ]]; then
    sudo cp '/etc/pam.d/common-auth' '/etc/pam.d/common-auth.orig'
  fi
  sudo sed --in-place "s/ max-tries=[0-9]\+ / max-tries=10 /g" '/etc/pam.d/common-auth'
  if ! fprintd-list "${USER}" | grep --quiet --fixed-strings 'right-index-finger'; then
    fprintd-enroll
  fi

  log 'Setting hybrid graphics'
  sudo system76-power graphics 'hybrid'

  log 'Updating firmware'
  sudo fwupdmgr refresh --force
  sudo fwupdmgr update --offline --assume-yes

  log 'Updating recovery partition'
  pop-upgrade recovery upgrade from-release

fi

# shellcheck disable=SC2016
log 'Finished
You may want to do any of the following:
- source ~/.bashrc && source ~/.nix-profile/etc/profile.d/nix.sh"
- jetbrains-toolbox
- reboot'
