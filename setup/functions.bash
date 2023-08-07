# source "$(dirname -- "${BASH_SOURCE[0]}")/../functions.bash"

#shellcheck disable=SC1091
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/functions.bash"

function auto_answer() {
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

service_exists() {
  local n=$1
  if [[ $(systemctl list-units --all --type=service --full --no-legend "$n.service" | sed 's/^\s*//g' | cut -f1 -d' ') == $n.service ]]; then
    return 0
  else
    return 1
  fi
}

# $1 = service unit file
function user_service_unit_file_exists() {
  systemctl --user list-unit-files --all --quiet "$1" > /dev/null
}

# $1 = service unit file
function enable_user_service_unit() {
  check_not_root
  check_exactly_1_arg "$@"
  if user_service_unit_file_exists "$1"; then
    if ! systemctl is-enabled --user --quiet "$1" && prompt_yn "Enable and start $1 user service?"; then
      log "Enabling and starting $1 user service"
      systemctl enable --now --user --quiet "$1"
      log "Enabled and started $1 user service"
    fi
  else
    log "User service unit files does not exist: $1"
  fi
}

# $1 = service unit file
function system_service_unit_file_exists() {
  systemctl --system list-unit-files --all --quiet "$1" > /dev/null
}

# $1 = service unit file
function enable_system_service_unit() {
  check_exactly_1_arg "$@"
  if system_service_unit_file_exists "$1"; then
    if ! systemctl is-enabled --system --quiet "$1" && prompt_yn "Enable and start $1 system service?"; then
      log "Enabling and starting $1 system service"
      sudo systemctl enable --now --system --quiet "$1"
      log "Enabled and started $1 system service"
    fi
  else
    log "System service unit files does not exist: $1"
  fi
}

# $1 = packages list type (cargo flatpaks nixpkgs snaps)
function get_packages_list() {
  check_exactly_1_arg "$@"
  case "$1" in
    cargo | flatpaks | nixpkgs | snaps) : ;;
    *) die "Unexpected package list type: $1" ;;
  esac
  local package_list_url="https://raw.githubusercontent.com/rvenutolo/packages/main/$1.csv"
  if is_personal && is_desktop; then
    local package_list_column=3
  elif is_personal && is_laptop; then
    local package_list_column=4
  elif is_work && is_laptop; then
    local package_list_column=5
  elif is_headless; then
    local package_list_column=6
  else
    die "Could not determine which computer this is"
  fi
  dl "${package_list_url}" | awk -F',' "\$${package_list_column} == \"y\" && \$7 == \"\" { print \$2 }"
}
