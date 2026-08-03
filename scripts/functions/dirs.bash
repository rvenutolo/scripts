#!/usr/bin/env bash

# @description Return true if the given path exists and is a directory.
# @arg $1 dir path
# @exitcode 0 if true
# @exitcode 1 if false
function dirs::exists() {
  args::check_exactly_1_arg "$@"
  [[ -d "$1" ]]
}

# @description Die if the given directory does not exist.
# @arg $1 dir path
# @exitcode 0 if true
# @exitcode 1 if false
function dirs::assert_exists() {
  args::check_exactly_1_arg "$@"
  local -r dir="$1"
  if ! dirs::exists "${dir}"; then
    log::die "${dir} does not exist"
  fi
}

# @description Create each given directory (and any missing parents) if it does not already exist.
# @arg $@ target directory paths
function dirs::create() {
  args::check_at_least_1_arg "$@"
  local dir
  for dir in "$@"; do
    if ! dirs::exists "${dir}"; then
      log::log "Creating ${dir}"
      mkdir --parents "${dir}"
      log::log "Created ${dir}"
    fi
  done
}

# @description Return true if the given directory is the same as, or nested under, ${PERSONAL_PROJECTS_DIR}.
#   Symlinks are resolved on both sides via realpath before comparison. The argument path need not exist.
# @arg $1 dir path
function dirs::is_personal_project() {
  args::check_exactly_1_arg "$@"
  local -r dir="$1"
  local dir_real personal_real
  dir_real="$(realpath --canonicalize-missing "${dir}")"
  personal_real="$(realpath "${PERSONAL_PROJECTS_DIR}")"
  [[ "${dir_real}" == "${personal_real}" || "${dir_real}" == "${personal_real}/"* ]]
}

# @description Die if the given directory is not under ${PERSONAL_PROJECTS_DIR}.
# @arg $1 dir path
# @exitcode 0 if true
# @exitcode 1 if false
function dirs::assert_personal_project() {
  args::check_exactly_1_arg "$@"
  local -r dir="$1"
  if ! dirs::is_personal_project "${dir}"; then
    log::die "${dir} is not under \${PERSONAL_PROJECTS_DIR} (${PERSONAL_PROJECTS_DIR})"
  fi
}

# @description Create each given directory (and any missing parents) as root if it does not already exist.
# @arg $@ target directory paths
function dirs::root_create() {
  args::check_at_least_1_arg "$@"
  local dir
  for dir in "$@"; do
    if ! dirs::exists "${dir}"; then
      log::log "Creating ${dir}"
      sudo mkdir --parents "${dir}"
      log::log "Created ${dir}"
    fi
  done
}
