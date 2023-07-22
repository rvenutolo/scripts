#!/usr/bin/env bash

# $ bash -c "$(wget -qO- 'https://raw.githubusercontent.com/rvenutolo/scripts/main/setup/_post-install/set-up-work-pop-os.sh')"
# $ bash -c "$(curl -fsLS 'https://raw.githubusercontent.com/rvenutolo/scripts/main/setup/_post-install/set-up-work-pop-os.sh')"

set -euo pipefail

readonly nixpkgs_url='https://raw.githubusercontent.com/rvenutolo/packages/main/nixpkgs.csv'
readonly flatpaks_url='https://raw.githubusercontent.com/rvenutolo/packages/main/flatpaks.csv'
readonly sdkman_url='https://raw.githubusercontent.com/rvenutolo/packages/main/sdkman.csv'
readonly dt_ip='172.16.0.21'

# $1 = URL
# $2 = output file (optional)
function dl() {
  log "Downloading: $1"
  if [[ -n "${2:-}" ]]; then
    tries=0
    until curl --disable --fail --silent --location --show-error "$1" --output "$2"; do
      ((tries += 1))
      if ((${tries} > 10)); then
        die "Failed to get in 10 tries: ${url}"
      fi
      sleep 15
    done
  else
    tries=0
    until curl --disable --fail --silent --location --show-error "$1"; do
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

# $1 = ip
function ipv4_to_num() {
  IFS=. read -r a b c d <<< "$1"
  echo "$(((a << 24) + (b << 16) + (c << 8) + d))"
}

function local_network() {
  local_ip="$(ip -oneline route get to '8.8.8.8' | sed --quiet 's/.*src \([0-9.]\+\).*/\1/p')"
  ip_num="$(ipv4_to_num "${local_ip}")"
  if [[ $(ipv4_to_num '10.0.0.0') -le "${ip_num}" && "${ip_num}" -le $(ipv4_to_num '10.255.255.255') ]]; then
    echo '10.0.0.0/8'
  elif [[ $(ipv4_to_num '172.16.0.0') -le "${ip_num}" && "${ip_num}" -le $(ipv4_to_num '172.31.255.255') ]]; then
    echo '172.16.0.0/12'
  elif [[ $(ipv4_to_num '192.168.0.0') -le "${ip_num}" && "${ip_num}" -le $(ipv4_to_num '192.168.255.255') ]]; then
    echo '192.168.0.0/16'
  else
    die "Could not determine local network IPv4 range"
  fi
}

if [[ "${EUID}" == 0 ]]; then
  die "Do not run this script as root"
fi

sudo --validate

log 'Setting sudo timeout'
echo 'Defaults timestamp_timeout=60' | sudo tee '/etc/sudoers.d/timestamp_timeout' > '/dev/null'

log 'Creating sshd config file'
sudo mkdir --parents '/etc/ssh/sshd_config.d'
echo "LogLevel VERBOSE
LoginGraceTime 20m
PermitRootLogin prohibit-password
PasswordAuthentication no
KbdInteractiveAuthentication no
AuthenticationMethods publickey
UsePAM yes
X11Forwarding yes
PrintMotd no
AcceptEnv LANG LC_*
AllowUsers ${USER}
" | sudo tee '/etc/ssh/sshd_config.d/sshd.conf' > '/dev/null'
sudo chmod 644 '/etc/ssh/sshd_config.d/sshd.conf'

log 'Setting timezone'
sudo timedatectl set-timezone 'America/New_York'

log 'Setting hostname'
hostnamectl set-hostname 'silverstar'

log 'Setting user to linger'
sudo loginctl enable-linger "${USER}"

log 'Adding to user groups'
groups=('sys' 'wheel' 'sudo' 'kvm' 'input' 'libvirtd')
for group in "${groups[@]}"; do
  sudo groupadd --force "${group}"
  sudo usermod --append --groups "${group}" "${USER}"
done

log 'Enabling gnome-remote-desktop service'
systemctl enable --now --user 'gnome-remote-desktop'

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

log 'Enabling ssh-agent service'
systemctl enable --now --user 'ssh-agent'

# Skip these if running in vm for testing.
if [[ ! -e '/dev/sr0' ]]; then

  log 'Installing fingerprint scanner packages'
  sudo apt-get install --yes fprintd libpam-fprintd
  sudo pam-auth-update --enable fprintd
  sudo cp '/etc/pam.d/common-auth' '/etc/pam.d/common-auth.orig'
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
  rsync --archive --human-readable --executability --relative "${dt_ip}:${file}" "${HOME}"
done

log 'Getting de-400 connection file'
dl_decrypt 'https://raw.githubusercontent.com/rvenutolo/crypt/main/misc/de-400.nmconnection' | sudo tee '/etc/NetworkManager/system-connections/de-400.nmconnection' > '/dev/null'
sudo chmod 600 '/etc/NetworkManager/system-connections/de-400.nmconnection'

# Do this before package upgrade as that may update the kernel, and then these
# commands will fail until after a reboot.
log 'Configuring UFW'
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from "$(local_network)"

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
  flatpak \
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
  openssh-server \
  ovmf \
  preload \
  python3-nautilus \
  qemu qemu-kvm qemu-utils \
  synaptic \
  virtinst

log 'Enabling libvirtd service'
sudo systemctl enable --now 'libvirtd'

# TODO check this
#log 'Enabling sshd service'
#sudo systemctl enable --now 'sshd'

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

if [[ ! -L "${HOME}/.local/share/fonts/nix" ]]; then
  log 'Updating font cache'
  mkdir --parents "${HOME}/.local/share/fonts"
  ln --symbolic --force "${HOME}/.nix-profile/share/fonts" "${HOME}/.local/share/fonts/nix"
  fc-cache --force
fi

log 'Installing flatpaks'
flatpak remote-add --user --if-not-exists 'flathub' 'https://dl.flathub.org/repo/flathub.flatpakrepo'
get_pkgs "${flatpaks_url}" | xargs flatpak install --or-update --user --noninteractive
if flatpak list --user --app | grep --quiet --fixed-strings 'com.google.Chrome'; then
  flatpak override --user --filesystem="${HOME}/.local/share" 'com.google.Chrome'
fi

if [[ ! -f "${HOME}/.sdkman/bin/sdkman-init.sh" ]]; then
  log 'Installing SDKMAN'
  if [[ -d "${HOME}/.sdkman" ]]; then
    # chezmoi will have created ~/.sdkman and the SDKMAN install script assumes
    # that the presence of this directory means that SDKMAN has already been
    # installed and will not actually install SDKMAN. This directory should only
    # contain a symlink to ~/.config/sdkman/config. This symlink will be
    # re-created later in this script.
    rm --recursive "${HOME}/.sdkman"
  fi
  # Retry due to random timeouts
  tries=0
  until dl 'https://get.sdkman.io?rcupdate=false' | bash; do
    ((tries += 1))
    if ((${tries} > 10)); then
      die "Failed to install SDKMAN in 10 tries"
    fi
    rm -rf "${HOME}/.sdkman"
    sleep 15
  done
fi

log 'Installing SDKMAN packages'
sed --in-place 's/sdkman_auto_answer=false/sdkman_auto_answer=true/g' "${HOME}/.sdkman/etc/config"
set +u
# shellcheck disable=SC1091
source "${HOME}/.sdkman/bin/sdkman-init.sh"
get_sdkman_pkgs | while read -r pkg; do
  log "Installing ${pkg} with SDKMAN"
  base_sleep_time=30
  tries=0
  until
    if [[ "${pkg}" == 'java' ]]; then
      sdk list java | grep --fixed-strings '|' | cut --delimiter='|' --fields='6' | grep '\-tem\s*$' | tac | while read -r jdk; do
        sdk install java "${jdk}"
      done
    else
      sdk install "${pkg}"
    fi
  do
    ((tries += 1))
    if ((${tries} > 10)); then
      die "Failed to install in 10 tries: ${pkg}"
    fi
    sleep "$((base_sleep_time * tries))"
  done
done
set -u

if [[ -f "${HOME}/.config/sdkman/config" ]]; then
  ln --symbolic --force "${HOME}/.config/sdkman/config" "${HOME}/.sdkman/etc/config"
fi

if [[ ! -e "${HOME}/.local/bin/jetbrains-toolbox" ]]; then
  log 'Installing JetBrains Toolbox'
  mkdir --parents "${HOME}/.local/share/JetBrains/Toolbox/bin"
  archive_url="$(dl 'https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release' | jq --raw-output '.TBA[0].downloads.linux.link')"
  dl "${archive_url}" | tar --extract --gzip --directory="${HOME}/.local/share/JetBrains/Toolbox/bin" --strip-components='1'
  chmod +x "${HOME}/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox"
  mkdir --parents "${HOME}/.local/bin"
  ln --symbolic --force "${HOME}/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox" "${HOME}/.local/bin/jetbrains-toolbox"
fi

source "${HOME}/.nix-profile/etc/profile.d/nix.sh"

log 'Updating tldr cache'
tldr --update

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

# shellcheck disable=SC2016
log 'Finished
You may want to do any of the following:
- source ~/.bashrc && source ~/.nix-profile/etc/profile.d/nix.sh"
- jetbrains-toolbox
- reboot'
