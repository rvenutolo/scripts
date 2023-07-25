# source "$(dirname -- "${BASH_SOURCE[0]}")/../functions.bash"

#shellcheck disable=SC1091
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/functions.bash"

function auto_answer() {
  ## TODO fix this
  [[ -n "${SCRIPTS_AUTO_ANSWER:-}" ]]
}

# $1 = question
function prompt_ny() {
  check_exactly_1_arg "$@"
  REPLY=''
  if auto_answer; then
    REPLY='n'
  fi
  while [[ "${REPLY}" != 'y' && "${REPLY}" != 'n' ]]; do
    read -rp "$1 [y/N]: "
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
  if auto_answer; then
    REPLY='y'
  fi
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
    if auto_answer; then
      REPLY="$2"
    fi
    if [[ "${REPLY}" == '' ]]; then
      read -rp "$1 [$2]: "
      if [[ "${REPLY}" == '' ]]; then
        REPLY="$2"
      fi
    fi
    echo "${REPLY}"
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
  mkdir --parents "$(dirname "$2")"
  ln --symbolic --force "$1" "$2"
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
    if ! systemctl status --user --quiet "$2"; then
      log "System service failed: $2"
      systemctl status --user "$2"
    fi
  fi
}

function enable_system_service() {
  check_exactly_2_args "$@"
  local service_file="/usr/lib/systemd/system/$2"
  if [[ ! -f "${service_file}" ]]; then
    log "Cannot enable $1 system service - service file is missing: ${service_file}"
    exit 0
  fi
  if ! systemctl is-enabled --system --quiet "$2" && prompt_yn "Enable and start $1 system service?"; then
    log "Enabling and starting $1 system service"
    sudo systemctl enable --now --system --quiet "$2"
    log "Enabled and started $1 system service"
    if ! systemctl status --system --quiet "$2"; then
      log "System service failed: $2"
      systemctl status --system "$2"
    fi
  fi
}

function get_system_num_for_packages_list() {
  if [[ -n "${PACKAGE_LISTS_COMPUTER_NUMBER:-}" ]]; then
    echo "$((PACKAGE_LISTS_COMPUTER_NUMBER + 2))"
    exit 0
  fi
  local computer_num=''
  while [[ -z "${computer_num}" ]]; do
    computer_num="$(prompt_for_value 'What computer number is this? [1: personal desktop, 2: personal laptop, 3: work laptop, 4: server]')"
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
