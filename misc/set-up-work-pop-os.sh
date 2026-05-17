#!/usr/bin/env bash

# @description Bootstrap a fresh Pop!_OS work machine: validates pre-conditions, sets hostname/timezone, installs apt + flatpak packages, runs the run-install-scripts and run-set-up-scripts driver scripts, applies dconf settings, installs GNOME extensions, and (when not in a VM) fetches encrypted secrets and configures the fingerprint scanner, recovery partition, hybrid graphics, and firmware.
# @noargs
# @exitcode 1 Pre-condition failure (run as root, pending package updates, reboot required, or any non-zero exit from the invoked apt/sudo/dconf/etc. commands).

# $ bash -c "$(wget -qO- 'https://raw.githubusercontent.com/rvenutolo/scripts/main/misc/set-up-work-pop-os.sh')"
# $ bash -c "$(curl -fsLS 'https://raw.githubusercontent.com/rvenutolo/scripts/main/misc/set-up-work-pop-os.sh')"

set -Eeuo pipefail
IFS=$'\n\t'
trap 'printf "\033[0;31m[%s %s] ERROR: line %s (exit %s): %s\033[0m\n" "$(date +%T)" "${0##*/}" "${LINENO}" "$?" "${BASH_COMMAND}" >&2' ERR

if ((BASH_VERSINFO[0] < 4)); then
  printf 'bash 4+ required\n' >&2
  exit 1
fi

# @description Print a timestamped info message to stderr.
# @arg $@ message Message text to log.
function log() {
  printf 'log [%s]: %s\n' "$(date +%T)" "$*" >&2
}

# @description Print a fatal error message with caller context and exit with status 1.
# @arg $@ message Error message text.
# @exitcode 1 Always exits with status 1.
function die() {
  printf 'DIE: %s (at %s:%s line %s.)\n' "$*" "${BASH_SOURCE[1]}" "${FUNCNAME[1]}" "${BASH_LINENO[0]}" >&2
  exit 1
}

# @description Download a URL via curl with retries (up to 10 attempts, 15s linear backoff). Writes to a file when an output path is given, otherwise streams to stdout.
# @arg $1 url URL to fetch.
# @arg $2 output_file Optional path to write downloaded bytes; omit to stream to stdout.
# @stdout Downloaded bytes (when no output_file argument is given).
# @exitcode 1 Failed to download after 10 retries.
function dl() {
  local -r url="$1"
  local -r output_file="${2:-}"
  log "Downloading: ${url}"
  if [[ -n "${output_file}" ]]; then
    local tries=0
    until curl --disable --fail --silent --location --show-error "${url}" --output "${output_file}"; do
      ((tries += 1))
      if ((tries > 10)); then
        die "Failed to get in 10 tries: ${url}"
      fi
      sleep 15
    done
  else
    local tries=0
    until curl --disable --fail --silent --location --show-error "${url}"; do
      ((tries += 1))
      if ((tries > 10)); then
        die "Failed to get in 10 tries: ${url}"
      fi
      sleep 15
    done
  fi
}

# @description Download a URL via dl() and decrypt the bytes with age using the user's age identity key. Writes to a file when an output path is given, otherwise streams the decrypted bytes to stdout.
# @arg $1 url URL of the age-encrypted payload to fetch.
# @arg $2 output_file Optional path to write decrypted bytes; omit to stream to stdout.
# @stdout Decrypted bytes (when no output_file argument is given).
# @exitcode 1 Download or age decryption failed.
function dl_decrypt() {
  local -r url="$1"
  local -r output_file="${2:-}"
  if [[ -n "${output_file}" ]]; then
    dl "${url}" | age --decrypt --identity "${HOME}/.keys/age.key" --output "${output_file}"
  else
    dl "${url}" | age --decrypt --identity "${HOME}/.keys/age.key"
  fi
}

function main() {
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
  sudo hostnamectl set-hostname 'silverstar'

  log 'Removing apt packages'
  sudo apt-get remove --yes geary firefox libreoffice-*

  log 'Running apt autoremove'
  sudo apt-get autoremove --yes

  log 'Installing apt packages'
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

  if [[ ! -f '/tmp/chezmoi' ]]; then
    log 'Installing chezmoi'
    bash -c "$(dl 'get.chezmoi.io')" -- -b '/tmp'
  fi
  if [[ ! -f "${HOME}/.config/bash/rc.bash" ]]; then
    log 'Initializing chezmoi'
    /tmp/chezmoi init --apply 'rvenutolo'
  fi

  # shellcheck disable=SC1091 # .profile is sourced from HOME, not a relative path
  source "${HOME}/.profile"

  log 'Running install scripts'
  SCRIPTS_AUTO_ANSWER='y' "${SCRIPTS_DIR}/run-install-scripts"

  log 'Running set up scripts'
  SCRIPTS_AUTO_ANSWER='y' "${SCRIPTS_DIR}/run-set-up-scripts"

  log 'Getting de-400 connection file'
  dl_decrypt 'https://raw.githubusercontent.com/rvenutolo/crypt/main/misc/de-400.nmconnection' \
    | sudo tee '/etc/NetworkManager/system-connections/de-400.nmconnection' > '/dev/null'
  sudo chmod 600 '/etc/NetworkManager/system-connections/de-400.nmconnection'

  log 'Setting dconf settings'
  local gsettings=(
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

  log 'Installing GNOME extensions'
  local gnome_extensions=(
    'https://extensions.gnome.org/extension/779/clipboard-indicator/'
    'https://extensions.gnome.org/extension/1319/gsconnect/'
    'https://extensions.gnome.org/extension/1460/vitals/'
  )
  for url in "${gnome_extensions[@]}"; do
    package_num="$(cut --delimiter='/' --fields=5 <<< "${url}")"
    log "Installing extension from URL: ${url}"
    gext --filesystem install "${package_num}"
  done

  log 'Adding autostart applications'
  mkdir --parents "${HOME}/.config/autostart"
  local autostart_files=(
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
    local home_dir_files_to_copy=(
      '.application-deployment'
      '.bin/create-emr-test-cluster'
      '.config/AWSVPNClient'
      '.de'
      '.var/app/com.slack.Slack'
      'carbonblack'
    )
    printf '%s\n' "${home_dir_files_to_copy[@]}" > '/tmp/home_dir_files_to_copy'
    rsync --archive --executability --recursive \
      --files-from='/tmp/home_dir_files_to_copy' \
      '172.16.0.157:/backup/work/home' "${HOME}"

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

  # shellcheck disable=SC2016 # single quotes intentional, multi-line literal text
  log 'Finished
You may want to do any of the following:
- source ~/.bashrc"
- jetbrains-toolbox
- reboot'
}

main "$@"
