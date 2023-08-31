#!/usr/bin/env bash

# $ bash -c "$(wget -qO- 'https://raw.githubusercontent.com/rvenutolo/scripts/main/misc/set-up-work-pop-os.sh')"
# $ bash -c "$(curl -fsLS 'https://raw.githubusercontent.com/rvenutolo/scripts/main/misc/set-up-work-pop-os.sh')"

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

log 'Setting sudo timeout'
echo 'Defaults timestamp_timeout=60' | sudo tee '/etc/sudoers.d/timestamp_timeout' > '/dev/null'

log 'Setting hostname'
hostnamectl set-hostname 'silverstar'

sudo apt-get update

if ! sudo apt-get --just-print dist-upgrade | grep --quiet '^0 upgraded'; then
  sudo touch '/var/run/reboot-required'
  die "Update/upgrade packages and reboot before running this script: sudo apt-get dist-upgrade --yes && sudo reboot"
fi
if [[ -f '/var/run/reboot-required' ]]; then
  die "Reboot before running this script"
fi

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
  "org.gnome.shell favorite-apps ['pop-cosmic-launcher.desktop', 'pop-cosmic-workspaces.desktop', 'pop-cosmic-applications.desktop', 'org.gnome.Nautilus.desktop', 'org.kde.krusader.desktop', 'com.alacritty.Alacritty.desktop', 'kitty.desktop', 'io.github.shiftey.Desktop.desktop', 'com.axosoft.GitKraken.desktop', 'awsvpnclient.desktop', 'com.brave.Browser.desktop', 'com.google.Chrome.desktop', 'com.slack.Slack.desktop', 'gnome-control-center.desktop']"
  'org.gnome.shell.extensions.dash-to-dock click-action minimize'
  'org.gnome.shell.extensions.dash-to-dock intellihide false'
  'org.gnome.shell.extensions.pop-shell active-hint true'
  'org.gnome.shell.weather automatic-location true'
  "org.gnome.shell.weather locations [<(uint32 2, <('Atlanta', 'KATL', true, [(0.58713361238621309, -1.4735281501968716)], [(0.5890310819891037, -1.4728481350137095)])>)>]"
  'org.gnome.system.location enabled true'
)
for line in "${gsettings[@]}"; do
  IFS=' ' read -r schema key value <<< "${line}"
  gsettings set "${schema}" "${key}" "${value}"
done

log 'Adding Docker key and repository'
# https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
sudo install --mode='0755' --directory '/etc/apt/keyrings'
curl --disable --fail --silent --location --show-error 'https://download.docker.com/linux/ubuntu/gpg' | sudo gpg --dearmor -o '/etc/apt/keyrings/docker.gpg'
sudo chmod 644 '/etc/apt/keyrings/docker.gpg'
# shellcheck disable=SC1091
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release --codename --short) stable" | sudo tee '/etc/apt/sources.list.d/docker.list' > /dev/null

log 'Removing apt packages'
sudo apt-get remove --yes geary firefox libreoffice-*

log 'Running apt autoremove'
sudo apt-get autoremove --yes

log 'Installing apt packages'
sudo apt update
sudo apt-get install --yes \
  age \
  alacritty \
  apt-transport-https \
  bridge-utils \
  ca-certificates \
  caffeine \
  clamav \
  cpu-checker \
  curl \
  dconf-editor \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose docker-compose-plugin \
  fail2ban \
  flatpak \
  git \
  gir1.2-nautilus-3.0 gir1.2-ebook-1.2 gir1.2-ebookcontacts-1.2 gir1.2-edataserver-1.2 \
  gnome-shell-extensions \
  gnome-shell-extension-gsconnect-browsers \
  gnome-software-plugin-flatpak gnome-tweaks \
  gnupg gnupg-agent \
  gparted \
  kitty \
  krusader \
  libfuse2 \
  libvirt-daemon libvirt-daemon-system libvirt-clients \
  nala \
  nano \
  nautilus-admin \
  nfs-kernel-server \
  micro \
  openssh-client openssh-server \
  ovmf \
  plocate \
  podman \
  preload \
  python3-nautilus \
  qemu qemu-kvm qemu-utils \
  software-properties-common \
  synaptic \
  uidmap \
  ufw \
  wget \
  virtinst \
  zip unzip

for script in "${SCRIPTS_DIR}/install/"*; do
  log "Running: ${script}"
  SCRIPTS_AUTO_ANSWER='y' "$script"
done

# shellcheck disable=1091
source "${HOME}/.nix-profile/etc/profile.d/nix.sh"

log 'Running setup scripts'
SCRIPTS_AUTO_ANSWER='y' "${SCRIPTS_DIR}/setup/run-setup-scripts"

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

log 'Setting Chrome as default web browser'
xdg-mime default 'com.google.Chrome.desktop' 'x-scheme-handler/https' 'x-scheme-handler/http'
xdg-settings set 'default-web-browser' 'com.google.Chrome.desktop'

# Skip these if running in vm for testing.
if [[ ! -e '/dev/sr0' ]]; then

  log 'Copying files from backup'
  home_dir_files_to_copy=(
    '.application-deployment'
    '.bin/create-emr-test-cluster'
    '.config/AWSVPNClient'
    '.de'
    '.var/app/com.slack.Slack'
    'carbonblack'
  )
  printf '%s\n' "${home_dir_files_to_copy[@]}" > '/tmp/home_dir_files_to_copy'
  rsync --archive --executability --recursive --files-from='/tmp/home_dir_files_to_copy' '172.16.0.157:/backup/work/home' "${HOME}"

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

  log 'Updating recovery partition'
  pop-upgrade recovery upgrade from-release

  log 'Setting hybrid graphics'
  sudo system76-power graphics 'hybrid'

  log 'Updating firmware'
  sudo fwupdmgr refresh --force
  sudo fwupdmgr update --offline --assume-yes

fi

# shellcheck disable=SC2016
log 'Finished
You may want to do any of the following:
- source ~/.bashrc"
- jetbrains-toolbox
- reboot'
