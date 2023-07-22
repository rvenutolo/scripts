#source "$(dirname -- "${BASH_SOURCE[0]}")/../functions.bash"

# shellcheck disable=SC1091
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/functions.bash"

# $1 = question
function prompt_ny() {
  check_exactly_1_arg "$@"
  REPLY=''
  while [[ "${REPLY}" != 'y' && "${REPLY}" != 'n' ]]; do
    read -rp "$1 [Y/n]: "
    if [[ ${REPLY} == [yY] ]]; then
      REPLY='y'
    elif [[ "${REPLY}" == '' || "${REPLY}" == [nN] ]]; then
      REPLY='n'
    fi
  done
  [[ "${REPLY}" == 'y' ]]
}

# $1 = question
function prompt_yn() {
  check_exactly_1_arg "$@"
  REPLY=''
  while [[ "${REPLY}" != 'y' && "${REPLY}" != 'n' ]]; do
    read -rp "$1 [Y/n]: "
    if [[ "${REPLY}" == '' || ${REPLY} == [yY] ]]; then
      REPLY='y'
    elif [[ "${REPLY}" == [nN] ]]; then
      REPLY='n'
    fi
  done
  [[ "${REPLY}" == 'y' ]]
}

# $1 = question
# $2 = default value (optional)
function prompt_for_value() {
  check_at_least_1_arg "$@"
  check_at_most_2_args "$@"
  if [[ -n "${2:-}" ]]; then
    REPLY=''
    read -rp "$1 [$2]: "
    if [[ -z "${REPLY}" ]]; then
      echo "$2"
    fi
  else
    REPLY=''
    while [[ -z "${REPLY}" ]]; do
      read -rp "$1: "
    done
    echo "${REPLY}"
  fi
}

# $1 = target file
# $2 = link file
function link_user_file() {
  check_not_root
  check_exactly_2_args "$@"
  if [[ ! -f "$1" ]]; then
    die "$1 does not exist"
  fi
  if [[ -L "$2" && "$(readlink --canonicalize "$2")" == "$(readlink --canonicalize "$1")" ]]; then
    exit 0
  fi
  if [[ -f "$2" ]]; then
    diff --color --unified "$2" "$1" || true
    if ! prompt_yn "$2 exists - Link: $1 -> $2?"; then
      exit 0
    fi
  else
    if ! prompt_yn "Link: $1 -> $2?"; then
      exit 0
    fi
  fi
  log "Linking: $1 -> $2"
  if [[ -f "$2" ]]; then
    rm "$2"
  fi
  mkdir --parents "$(dirname "$2")"
  ln --symbolic "$1" "$2"
  log "Linked: $1 -> $2"
}

# $1 = target file
# $2 = link file
function link_system_file() {
  check_exactly_2_args "$@"
  if [[ ! -f "$1" ]]; then
    die "$1 does not exist"
  fi
  if [[ -L "$2" && "$(readlink --canonicalize "$2")" == "$(readlink --canonicalize "$1")" ]]; then
    exit 0
  fi
  if [[ -f "$2" ]]; then
    diff --color --unified "$2" "$1" || true
    if ! prompt_yn "$2 exists - Link: $1 -> $2?"; then
      exit 0
    fi
  else
    if ! prompt_yn "Link: $1 -> $2?"; then
      exit 0
    fi
  fi
  log "Linking: $1 -> $2"
  if [[ -f "$2" ]]; then
    sudo rm "$2"
  fi
  sudo mkdir --parents "$(dirname "$2")"
  sudo ln --symbolic "$1" "$2"
  log "Linked: $1 -> $2"
}

# $1 = old file location
# $2 = new file location
function move_user_file() {
  check_not_root
  check_exactly_2_args "$@"
  if [[ ! -f "$1" ]]; then
    die "$1 does not exist"
  fi
  if [[ "$1" == "$2" ]]; then
    die "File paths are the same"
  fi
  if [[ -f "$2" ]]; then
    diff --color --unified "$2" "$1" || true
    if ! prompt_yn "$2 exists - Overwrite: $1 -> $2?"; then
      exit 0
    fi
  else
    if ! prompt_yn "Move $1 -> $2?"; then
      exit 0
    fi
  fi
  log "Moving: $1 -> $2"
  mkdir --parents "$(dirname "$2")"
  mv "$1" "$2"
  log "Moved: $1 -> $2"
}

# $1 = old file location
# $2 = new file location
function copy_user_file() {
  check_not_root
  check_exactly_2_args "$@"
  if [[ ! -f "$1" ]]; then
    die "$1 does not exist"
  fi
  if [[ "$1" == "$2" ]]; then
    die "File paths are the same"
  fi
  if [[ -f "$2" ]]; then
    if cmp --silent "$1" "$2"; then
      exit 0
    else
      diff --color --unified "$2" "$1" || true
      if ! prompt_yn "$2 exists - Overwrite: $1 -> $2?"; then
        exit 0
      fi
    fi
  else
    if ! prompt_yn "Copy $1 -> $2?"; then
      exit 0
    fi
  fi
  log "Copying: $1 -> $2"
  mkdir --parents "$(dirname "$2")"
  cp "$1" "$2"
  log "Copied: $1 -> $2"
}

# $1 = old file location
# $2 = new file location
function copy_system_file() {
  check_exactly_2_args "$@"
  if [[ ! -f "$1" ]]; then
    die "$1 does not exist"
  fi
  if [[ "$1" == "$2" ]]; then
    die "File paths are the same"
  fi
  if [[ -f "$2" ]]; then
    if cmp --silent "$1" "$2"; then
      exit 0
    else
      diff --color --unified "$2" "$1" || true
      if ! prompt_yn "$2 exists - Overwrite: $1 -> $2?"; then
        exit 0
      fi
    fi
  else
    if ! prompt_yn "Copy $1 -> $2?"; then
      exit 0
    fi
  fi
  log "Copying: $1 -> $2"
  sudo mkdir --parents "$(dirname "$2")"
  sudo cp "$1" "$2"
  log "Copied: $1 -> $2"
}

# $1 service description
# $2 service unit
function enable_user_service() {
  check_not_root
  check_exactly_2_args "$@"
  local service_file="${XDG_CONFIG_HOME}/systemd/user/$2"
  if [[ ! -f "${service_file}" ]]; then
    log "Cannot enable $1 user service - service file is missing: ${service_file}"
    exit 0
  fi
  if ! systemctl is-enabled --user --quiet "$2" && prompt_yn "Enable and start $1 user service?"; then
    log "Enabling and starting $1 user service"
    systemctl enable --now --user --quiet "$2"
    log "Enabled and started $1 user service"
  fi
  if ! systemctl is-active --user --quiet "$2" && prompt_yn "Start $1 user service?"; then
    log "Starting $1 user service"
    systemctl start --user --quiet "$2"
    log "Started $1 user service"
  fi
}

function enable_system_service() {
  check_exactly_2_args "$@"
  local service_file="/usr/lib/systemd/system/$2"
  if [[ ! -f "${service_file}" ]]; then
    log "Cannot enable $1 system service - service file is missing: ${service_file}"
    exit 0
  fi
  if ! sudo systemctl is-enabled --systeem --quiet "$2" && prompt_yn "Enable and start $1 system service?"; then
    log "Enabling and starting $1 system service"
    systemctl enable --now --system --quiet "$2"
    log "Enabled and started $1 system service"
  fi
  if ! systemctl is-active --system --quiet "$2" && prompt_yn "Start $1 system service?"; then
    log "Starting $1 system service"
    systemctl start --system --quiet "$2"
    log "Started $1 system service"
  fi
}

function get_system_num_for_packages_list() {
  # PERSONAL DESKTOP - 3
  # PERSONAL LAPTOP - 4
  # WORK LAPTOP - 5
  # SERVER -6
  (
    echo '1 - personal desktop'
    echo '2 - personal laptop'
    echo '3 - work laptop'
    echo '4 - personal server'
  )
  local computer_num=''
  while [[ -z "${computper_num}" ]]; do
    computer_num="$(prompt_for_value 'What computer is this?')"
    case "${computer_num}" in
      1 | 2 | 3 | 4)
        ((computer_num += 2))
        echo "${computer_num}"
        ;;
      *) computer_num='' ;;
    esac
  done
}

# $1 = packages list type (cargo flatpaks nixpkgs snaps)
function get_packages_list() {
  check_exactly_1_arg "$@"
  case "$1" in
    cargo | flatpaks | nixpkgs | snaps) : ;;
    *) die "Unexpected package list type: $1" ;;
  esac
  local package_list_url
  package_list_url="https://raw.githubusercontent.com/rvenutolo/packages/main/$1.csv"
  local package_list_column
  package_list_column="$(get_system_num_for_packages_list)"
  dl "${package_list_url}" | awk -F',' "\$${package_list_column} == \"y\" && \$7 == \"\" { print \$2 }"
}
