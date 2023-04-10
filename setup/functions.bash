#source "$(dirname -- "${BASH_SOURCE[0]}")/../functions.bash"

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
# $2 = default value
function prompt_for_value() {
  check_exactly_2_args "$@"
  REPLY=''
  read -rp "$1 [$2]: "
  if [[ -z "${REPLY}" ]]; then
    echo "$2"
  else
    echo "${REPLY}"
  fi
}

# $1 = target file
# $2 = link file
function link_user_file() {
  check_exactly_2_args "$@"
  if [[ ! -f "$1" ]]; then
    log "$1 does not exist"
    exit 2
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
    log "$1 does not exist"
    exit 2
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
  check_exactly_2_args "$@"
  if [[ ! -f "$1" ]]; then
    log "$1 does not exist"
    exit 2
  fi
  if [[ "$1" == "$2" ]]; then
    log "File paths are the same"
    exit 2
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
  check_exactly_2_args "$@"
  if [[ ! -f "$1" ]]; then
    log "$1 does not exist"
    exit 2
  fi
  if [[ "$1" == "$2" ]]; then
    log "File paths are the same"
    exit 2
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
    log "$1 does not exist"
    exit 2
  fi
  if [[ "$1" == "$2" ]]; then
    log "File paths are the same"
    exit 2
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

# $1 service unit
# $2 'user' or 'system'
function get_service_file() {
  check_exactly_2_args "$@"
  if [[ "$2" == 'system' ]]; then
    echo "/usr/lib/systemd/system/$1"
  elif [[ "$2" == 'user' ]]; then
    echo "${XDG_CONFIG_HOME}/systemd/user/$1"
  else
    log "unexpected value: $2"
    exit 0
  fi
}

# $1 service description
# $2 service unit
# $3 required executable
# $4 'system' or 'user'
function enable_service() {
  check_exactly_4_args
  if ! executable_exists "$3"; then
    log "$3 not found -- Not enabling $1 service"
    exit 0
  fi
  if [[ "$4" == 'system' ]]; then
      local service_file="/usr/lib/systemd/system/$1"
    elif [[ "$4" == 'user' ]]; then
      local service_file="${XDG_CONFIG_HOME}/systemd/user/$1"
    else
      log "unexpected value: $4"
      exit 0
    fi
  if [[ ! -f "${service_file}" ]]; then
    log "Cannot enable $1 service - service file is missing: ${service_file}"
    exit 0
  fi
  if ! systemctl is-enabled --"$4" --quiet "$2" && prompt_yn "Enable and start $1 service?"; then
    log "Enabling and starting $1 service"
    systemctl enable --now --"$4" --quiet "$2"
    log "Enabled and started $1 service"
  fi
  if ! systemctl is-active --"$4" --quiet "$2" && prompt_yn "Start $1 service?"; then
    log "Starting $1 service"
    systemctl start --"$4" --quiet "$2"
    log "Started $1 service"
  fi
}
