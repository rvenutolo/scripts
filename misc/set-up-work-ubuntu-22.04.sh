#!/usr/bin/env bash

# @description Bootstrap a fresh Ubuntu 22.04 work machine: validates pre-conditions, sets hostname, installs apt + flatpak packages (including the nvidia-detector driver), runs the run-install-scripts and run-set-up-scripts driver scripts, applies dconf settings, installs GNOME extensions, and (when not in a VM) installs system76-power and updates firmware.
# @noargs
# @exitcode 1 Pre-condition failure (run as root, pending package updates, reboot required, or any non-zero exit from the invoked apt/sudo/dconf/etc. commands).

# $ bash -c "$(wget -qO- 'https://raw.githubusercontent.com/rvenutolo/scripts/main/misc/set-up-work-ubuntu-22.04.sh')"
# $ bash -c "$(curl -fsLS 'https://raw.githubusercontent.com/rvenutolo/scripts/main/misc/set-up-work-ubuntu-22.04.sh')"

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

  log 'Setting hostname'
  sudo hostnamectl set-hostname 'silverstar'

  log 'Removing apt packages'
  sudo apt-get remove --yes firefox

  log 'Running apt autoremove'
  sudo apt-get autoremove --yes

  log 'Installing apt packages'
  sudo add-apt-repository 'ppa:aslatter/ppa' --yes
  sudo apt-get install --yes \
    "$(nvidia-detector)" \
    age \
    alacritty \
    apt-transport-https \
    bridge-utils \
    ca-certificates \
    caffeine \
    chrome-gnome-shell \
    clamav \
    cpu-checker \
    curl \
    dconf-editor \
    fail2ban \
    flatpak \
    git \
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
    python3-nautilus \
    qemu qemu-kvm qemu-utils \
    software-properties-common \
    synaptic \
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

  # shellcheck disable=SC1091 # .bash_profile is sourced from HOME, not a relative path
  source "${HOME}/.bash_profile"

  log 'Running install scripts'
  "${SCRIPTS_DIR}/run-install-scripts"

  log 'Running set up scripts'
  "${SCRIPTS_DIR}/run-set-up-scripts"

  log 'Setting dconf settings'
  local gsettings=(
    'org.gnome.desktop.background picture-uri-dark file:///usr/share/backgrounds/Optical_Fibers_in_Dark_by_Elena_Stravoravdi.jpg'
    'org.gnome.desktop.background primary-color #000000'
    'org.gnome.desktop.background secondary-color #000000'
    'org.gnome.desktop.datetime automatic-timezone false'
    "org.gnome.desktop.input-sources xkb-options ['caps:super']"
    'org.gnome.desktop.interface clock-format 12h'
    'org.gnome.desktop.interface clock-show-weekday true'
    'org.gnome.desktop.interface color-scheme prefer-dark'
    'org.gnome.desktop.interface gtk-theme Yaru-blue-dark'
    'org.gnome.desktop.interface icon-theme Yaru-blue'
    'org.gnome.desktop.interface locate-pointer true'
    'org.gnome.desktop.interface show-battery-percentage true'
    'org.gnome.desktop.media-handling autorun-never true'
    "org.gnome.desktop.notifications application-children ['org-gnome-software', 'gnome-power-panel']"
    'org.gnome.desktop.peripherals.touchpad natural-scroll false'
    'org.gnome.desktop.peripherals.touchpad speed 0.2'
    'org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled true'
    'org.gnome.desktop.screensaver lock-delay uint32 30'
    'org.gnome.desktop.screensaver picture-uri file:///usr/share/backgrounds/Optical_Fibers_in_Dark_by_Elena_Stravoravdi.jpg'
    'org.gnome.desktop.screensaver primary-color #000000'
    'org.gnome.desktop.screensaver secondary-color #000000'
    'org.gnome.desktop.session idle-delay uint32 900'
    'org.gnome.desktop.wm.preferences action-middle-click-titlebar toggle-shade'
    'org.gnome.desktop.wm.preferences button-layout appmenu:minimize,maximize,close'
    'org.gnome.gedit.preferences.editor scheme Yaru-dark'
    'org.gnome.mutter center-new-windows true'
    'org.gnome.settings-daemon.plugins.color night-light-enabled true'
    'org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 7200'
    'org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type suspend'
    'org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 1800'
    'org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type suspend'
    'org.gnome.shell.extensions.dash-to-dock click-action minimize'
    'org.gnome.shell.extensions.dash-to-dock intellihide false'
    'org.gnome.shell.extensions.ding show-home false'
    'org.gnome.shell.extensions.ding show-trash false'
    "org.gnome.shell favorite-apps ['org.gnome.Nautilus.desktop', 'com.alacritty.Alacritty.desktop', 'kitty.desktop', 'com.google.Chrome.desktop', 'com.slack.Slack.desktop', 'org.kde.kate.desktop', 'jetbrains-idea-999b9024-908d-49d8-9161-20fb056d49b6.desktop', 'jetbrains-datagrip-207e01d1-8176-441d-ba23-0f1702bc4b2f.desktop', 'io.github.shiftey.Desktop.desktop', 'com.axosoft.GitKraken.desktop', 'org.gnome.tweaks.desktop', 'gnome-control-center.desktop']"
    'org.gnome.shell.weather automatic-location true'
    "org.gnome.shell.weather locations [<(uint32 2, <('Atlanta', 'KATL', true, [(0.58713361238621309, -1.4735281501968716)], [(0.5890310819891037, -1.4728481350137095)])>)>]"
    'org.gnome.system.location enabled true'
    'org.gtk.Settings.FileChooser clock-format 12h'
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
    'https://extensions.gnome.org/extension/750/openweather/'
  )
  for url in "${gnome_extensions[@]}"; do
    package_num="$(cut --delimiter='/' --fields=5 <<< "${url}")"
    log "Installing extension from URL: ${url}"
    gext --filesystem install "${package_num}"
  done

  log 'Setting Chrome as default web browser'
  xdg-mime default 'com.google.Chrome.desktop' 'x-scheme-handler/https' 'x-scheme-handler/http'
  xdg-settings set 'default-web-browser' 'com.google.Chrome.desktop'

  # Skip these if running in vm for testing.
  if [[ ! -e '/dev/sr0' ]]; then

    log 'Installing system76-power'
    sudo add-apt-repository 'ppa:system76-dev/stable' --yes
    sudo apt-get install --yes system76-power gnome-shell-extension-system76-power gnome-shell-extension-prefs
    sudo system76-power graphics 'hybrid'

    log 'Updating firmware'
    sudo fwupdmgr refresh --force
    sudo fwupdmgr update --offline --assume-yes

  fi

  # shellcheck disable=SC2016 # single quotes intentional, multi-line literal text
  log 'Finished
You may want to do any of the following:
- source ~/.bash_profile"
- jetbrains-toolbox
- reboot'
}

main "$@"
