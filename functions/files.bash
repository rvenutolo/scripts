#!/usr/bin/env bash

# @description Return true if the given path exists and is a regular file.
# @arg $1 file path
function files::exists() {
  args::check_exactly_1_arg "$@"
  [[ -f "$1" ]]
}

# @description Die if the given file does not exist.
# @arg $1 file path
# @exitcode 0 if true
# @exitcode 1 if false
function files::assert_exists() {
  args::check_exactly_1_arg "$@"
  local -r file="$1"
  if ! files::exists "${file}"; then
    log::die "${file} does not exist"
  fi
}

# @description Return true if the given path exists as any filesystem entry (regular file, directory, symlink, device, etc.).
# @arg $1 path to test
# @exitcode 0 if true
# @exitcode 1 if false
function files::any_exists() {
  args::check_exactly_1_arg "$@"
  [[ -e "$1" ]]
}

# @description Return true if the given file exists and is readable.
# @arg $1 file path
# @exitcode 0 if true
# @exitcode 1 if false
function files::is_readable() {
  args::check_exactly_1_arg "$@"
  [[ -r "$1" ]]
}

# @description Print the size of a file in gigabytes (two decimal places).
# Output: stdout — size in GB, e.g. "1.23"
# @arg $1 file path
function files::size_gb() {
  args::check_exactly_1_arg "$@"
  local -r file="$1"
  files::assert_exists "${file}"
  printf '%s\n' "scale=2; $(stat --format='%s' "${file}") / 1073741824" | bc
}

# @description Move a file, prompting if the destination already exists; skips if source and dest are byte-identical.
# @arg $1 source file path
# @arg $2 destination file path
function files::move() {
  args::check_exactly_2_args "$@"
  local -r src="$1"
  local -r dest="$2"
  files::assert_exists "${src}"
  if [[ "${src}" == "${dest}" ]]; then
    log::die "File paths are the same"
  fi
  if files::exists "${dest}"; then
    if cmp --silent "${src}" "${dest}"; then
      rm --force -- "${src}"
      return 0
    else
      diff --color --unified "${dest}" "${src}" || true
      if ! prompt::yn "${dest} exists - Overwrite: ${src} -> ${dest}?"; then
        return 0
      fi
    fi
  else
    if ! prompt::yn "Move ${src} -> ${dest}?"; then
      return 0
    fi
  fi
  log::log "Moving: ${src} -> ${dest}"
  dirs::create "$(dirname "${dest}")"
  mv -- "${src}" "${dest}"
  log::log "Moved: ${src} -> ${dest}"
}

# @description Move a file quietly, prompting if the destination already exists; skips if source and dest are byte-identical.
# Like files::move but suppresses the "Moving/Moved" log messages.
# @arg $1 source file path
# @arg $2 destination file path
function files::move_quiet() {
  args::check_exactly_2_args "$@"
  local -r src="$1"
  local -r dest="$2"
  files::assert_exists "${src}"
  if [[ "${src}" == "${dest}" ]]; then
    log::die "File paths are the same"
  fi
  if files::exists "${dest}"; then
    if cmp --silent "${src}" "${dest}"; then
      rm --force -- "${src}"
      return 0
    else
      diff --color --unified "${dest}" "${src}" || true
      if ! prompt::yn "${dest} exists - Overwrite: ${src} -> ${dest}?"; then
        return 0
      fi
    fi
  else
    if ! prompt::yn "Move ${src} -> ${dest}?"; then
      return 0
    fi
  fi
  dirs::create "$(dirname "${dest}")"
  mv -- "${src}" "${dest}"
}

# @description Move a file without prompting, overwriting destination if it exists. For programmatic temp-file-to-dest moves
# where interactive confirmation would be inappropriate. Creates parent directory of destination if needed.
# @arg $1 source file path
# @arg $2 destination file path
function files::move_no_prompt() {
  args::check_exactly_2_args "$@"
  local -r src="$1"
  local -r dest="$2"
  files::assert_exists "${src}"
  if [[ "${src}" == "${dest}" ]]; then
    log::die "File paths are the same"
  fi
  log::log "Moving: ${src} -> ${dest}"
  dirs::create "$(dirname "${dest}")"
  mv --force -- "${src}" "${dest}"
  log::log "Moved: ${src} -> ${dest}"
}

# @description Move a file quietly without prompting, overwriting destination if it exists. Creates parent directory of
# destination if needed. Like files::move_no_prompt but suppresses the "Moving/Moved" log messages.
# @arg $1 source file path
# @arg $2 destination file path
function files::move_no_prompt_quiet() {
  args::check_exactly_2_args "$@"
  local -r src="$1"
  local -r dest="$2"
  files::assert_exists "${src}"
  if [[ "${src}" == "${dest}" ]]; then
    log::die "File paths are the same"
  fi
  dirs::create "$(dirname "${dest}")"
  mv --force -- "${src}" "${dest}"
}

# @description Move a file as root, prompting if the destination already exists; skips if byte-identical.
# @arg $1 source file path
# @arg $2 destination file path
function files::root_move() {
  args::check_exactly_2_args "$@"
  local -r src="$1"
  local -r dest="$2"
  files::assert_exists "${src}"
  if [[ "${src}" == "${dest}" ]]; then
    log::die "File paths are the same"
  fi
  if sudo test -f "${dest}"; then
    if sudo cmp --silent "${src}" "${dest}"; then
      sudo rm --force -- "${src}"
      return 0
    else
      sudo diff --color --unified "${dest}" "${src}" || true
      if ! prompt::yn "${dest} exists - Overwrite: ${src} -> ${dest}?"; then
        return 0
      fi
    fi
  else
    if ! prompt::yn "Move ${src} -> ${dest}?"; then
      return 0
    fi
  fi
  log::log "Moving: ${src} -> ${dest}"
  dirs::root_create "$(dirname "${dest}")"
  sudo mv -- "${src}" "${dest}"
  log::log "Moved: ${src} -> ${dest}"
}

# @description Move a file as root quietly, prompting if the destination already exists; skips if byte-identical.
# Like files::root_move but suppresses the "Moving/Moved" log messages.
# @arg $1 source file path
# @arg $2 destination file path
function files::root_move_quiet() {
  args::check_exactly_2_args "$@"
  local -r src="$1"
  local -r dest="$2"
  files::assert_exists "${src}"
  if [[ "${src}" == "${dest}" ]]; then
    log::die "File paths are the same"
  fi
  if sudo test -f "${dest}"; then
    if sudo cmp --silent "${src}" "${dest}"; then
      sudo rm --force -- "${src}"
      return 0
    else
      sudo diff --color --unified "${dest}" "${src}" || true
      if ! prompt::yn "${dest} exists - Overwrite: ${src} -> ${dest}?"; then
        return 0
      fi
    fi
  else
    if ! prompt::yn "Move ${src} -> ${dest}?"; then
      return 0
    fi
  fi
  dirs::root_create "$(dirname "${dest}")"
  sudo mv -- "${src}" "${dest}"
}

# @description Copy a file, prompting if the destination already exists; skips if byte-identical.
# @arg $1 source file path
# @arg $2 destination file path
function files::copy() {
  args::check_exactly_2_args "$@"
  local -r src="$1"
  local -r dest="$2"
  files::assert_exists "${src}"
  if [[ "${src}" == "${dest}" ]]; then
    log::die "File paths are the same"
  fi
  if files::exists "${dest}"; then
    if cmp --silent "${src}" "${dest}"; then
      return 0
    else
      diff --color --unified "${dest}" "${src}" || true
      if ! prompt::yn "${dest} exists - Overwrite: ${src} -> ${dest}?"; then
        return 0
      fi
    fi
  else
    if ! prompt::yn "Copy ${src} -> ${dest}?"; then
      return 0
    fi
  fi
  log::log "Copying: ${src} -> ${dest}"
  dirs::create "$(dirname "${dest}")"
  cp "${src}" "${dest}"
  log::log "Copied: ${src} -> ${dest}"
}

# @description Copy a file quietly, prompting if the destination already exists; skips if byte-identical.
# Like files::copy but suppresses the "Copying/Copied" log messages.
# @arg $1 source file path
# @arg $2 destination file path
function files::copy_quiet() {
  args::check_exactly_2_args "$@"
  local -r src="$1"
  local -r dest="$2"
  files::assert_exists "${src}"
  if [[ "${src}" == "${dest}" ]]; then
    log::die "File paths are the same"
  fi
  if files::exists "${dest}"; then
    if cmp --silent "${src}" "${dest}"; then
      return 0
    else
      diff --color --unified "${dest}" "${src}" || true
      if ! prompt::yn "${dest} exists - Overwrite: ${src} -> ${dest}?"; then
        return 0
      fi
    fi
  else
    if ! prompt::yn "Copy ${src} -> ${dest}?"; then
      return 0
    fi
  fi
  dirs::create "$(dirname "${dest}")"
  cp "${src}" "${dest}"
}

# @description Copy a file as root, prompting if the destination already exists; skips if byte-identical.
# @arg $1 source file path
# @arg $2 destination file path
function files::root_copy() {
  args::check_exactly_2_args "$@"
  local -r src="$1"
  local -r dest="$2"
  files::assert_exists "${src}"
  if [[ "${src}" == "${dest}" ]]; then
    log::die "File paths are the same"
  fi
  if sudo test -f "${dest}"; then
    if sudo cmp --silent "${src}" "${dest}"; then
      return 0
    else
      sudo diff --color --unified "${dest}" "${src}" || true
      if ! prompt::yn "${dest} exists - Overwrite: ${src} -> ${dest}?"; then
        return 0
      fi
    fi
  else
    if ! prompt::yn "Copy ${src} -> ${dest}?"; then
      return 0
    fi
  fi
  log::log "Copying: ${src} -> ${dest}"
  dirs::root_create "$(dirname "${dest}")"
  sudo cp "${src}" "${dest}"
  log::log "Copied: ${src} -> ${dest}"
}

# @description Copy a file as root quietly, prompting if the destination already exists; skips if byte-identical.
# Like files::root_copy but suppresses the "Copying/Copied" log messages.
# @arg $1 source file path
# @arg $2 destination file path
function files::root_copy_quiet() {
  args::check_exactly_2_args "$@"
  local -r src="$1"
  local -r dest="$2"
  files::assert_exists "${src}"
  if [[ "${src}" == "${dest}" ]]; then
    log::die "File paths are the same"
  fi
  if sudo test -f "${dest}"; then
    if sudo cmp --silent "${src}" "${dest}"; then
      return 0
    else
      sudo diff --color --unified "${dest}" "${src}" || true
      if ! prompt::yn "${dest} exists - Overwrite: ${src} -> ${dest}?"; then
        return 0
      fi
    fi
  else
    if ! prompt::yn "Copy ${src} -> ${dest}?"; then
      return 0
    fi
  fi
  dirs::root_create "$(dirname "${dest}")"
  sudo cp "${src}" "${dest}"
}

# @description Write content to a file, prompting if the file already exists; skips if content is identical.
# @arg $1 file path
# @arg $2 content to write
function files::write() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r content="$2"
  if files::exists "${file}"; then
    if [[ "$(< "${file}")" == "${content}" ]]; then
      return 0
    else
      diff --color --unified "${file}" - <<< "${content}" || true
      if ! prompt::yn "${file} exists - Overwrite?"; then
        return 0
      fi
    fi
  fi
  log::log "Writing ${file}"
  dirs::create "$(dirname "${file}")"
  printf '%s\n' "${content}" > "${file}"
  log::log "Wrote ${file}"
}

# @description Write content to a file quietly, prompting if the file already exists; skips if content is identical.
# Like files::write but suppresses the "Writing/Wrote" log messages.
# @arg $1 file path
# @arg $2 content to write
function files::write_quiet() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r content="$2"
  if files::exists "${file}"; then
    if [[ "$(< "${file}")" == "${content}" ]]; then
      return 0
    else
      diff --color --unified "${file}" - <<< "${content}" || true
      if ! prompt::yn "${file} exists - Overwrite?"; then
        return 0
      fi
    fi
  fi
  dirs::create "$(dirname "${file}")"
  printf '%s\n' "${content}" > "${file}"
}

# @description Write content to a root-owned file, prompting if the file already exists; skips if content is identical.
# @arg $1 file path
# @arg $2 content to write
function files::root_write() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r content="$2"
  if files::exists "${file}"; then
    if [[ "$(sudo cat "${file}")" == "${content}" ]]; then
      return 0
    else
      sudo diff --color --unified "${file}" - <<< "${content}" || true
      if ! prompt::yn "${file} exists - Overwrite?"; then
        return 0
      fi
    fi
  fi
  log::log "Writing ${file}"
  dirs::root_create "$(dirname "${file}")"
  printf '%s\n' "${content}" | sudo tee "${file}" > '/dev/null'
  log::log "Wrote ${file}"
}

# @description Write content to a root-owned file quietly, prompting if the file already exists; skips if content is identical.
# Like files::root_write but suppresses the "Writing/Wrote" log messages.
# @arg $1 file path
# @arg $2 content to write
function files::root_write_quiet() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r content="$2"
  if files::exists "${file}"; then
    if [[ "$(sudo cat "${file}")" == "${content}" ]]; then
      return 0
    else
      sudo diff --color --unified "${file}" - <<< "${content}" || true
      if ! prompt::yn "${file} exists - Overwrite?"; then
        return 0
      fi
    fi
  fi
  dirs::root_create "$(dirname "${file}")"
  printf '%s\n' "${content}" | sudo tee "${file}" > '/dev/null'
}

# @description Append content to a file, creating the file and any missing parent directories as needed.
# @arg $1 file path
# @arg $2 content to append
function files::append_to() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r content="$2"
  log::log "Appending to ${file}"
  dirs::create "$(dirname "${file}")"
  printf '%s\n' "${content}" >> "${file}"
  log::log "Appended to ${file}"
}

# @description Append content to a file quietly, creating the file and any missing parent directories as needed.
# Like files::append_to but suppresses the "Appending/Appended" log messages.
# @arg $1 file path
# @arg $2 content to append
function files::append_to_quiet() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r content="$2"
  dirs::create "$(dirname "${file}")"
  printf '%s\n' "${content}" >> "${file}"
}

# @description Append content to a root-owned file, creating the file and any missing parent directories as needed.
# @arg $1 file path
# @arg $2 content to append
function files::root_append_to() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r content="$2"
  log::log "Appending to ${file}"
  dirs::root_create "$(dirname "${file}")"
  printf '%s\n' "${content}" | sudo tee --append "${file}" > '/dev/null'
  log::log "Appended to ${file}"
}

# @description Append content to a root-owned file quietly, creating the file and any missing parent directories as needed.
# Like files::root_append_to but suppresses the "Appending/Appended" log messages.
# @arg $1 file path
# @arg $2 content to append
function files::root_append_to_quiet() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r content="$2"
  dirs::root_create "$(dirname "${file}")"
  printf '%s\n' "${content}" | sudo tee --append "${file}" > '/dev/null'
}

# Internal: accumulated temp file paths cleaned up by the shared EXIT trap installed
# on first call to files::create_temp. Multiple files::create_temp calls all funnel into
# this list so each call does NOT clobber the previous call's trap.
_FILES_CREATE_TEMP_PATHS=()
_FILES_CREATE_TEMP_TRAP_INSTALLED='n'

# @description Internal cleanup function bound to EXIT by files::create_temp on first
# call. Iterates the accumulated paths and removes each. Safe to invoke directly for testing.
# @noargs
function _files::create_temp_cleanup() {
  if ((${#_FILES_CREATE_TEMP_PATHS[@]} > 0)); then
    rm --force -- "${_FILES_CREATE_TEMP_PATHS[@]}"
  fi
}

# @description Create a temporary file and ensure it is removed when the calling shell exits.
# Sets the named variable in the caller's scope to the temp file path. Safe to call multiple
# times in the same process — every created path is collected into a shared list and cleaned
# up by a single EXIT trap installed on the first call. Must be called as a direct function
# (not via command substitution) so the EXIT trap is installed in the calling process and the
# accumulated paths array lives in the caller's shell. NOTE: the trap is installed via
# `trap _files::create_temp_cleanup EXIT`, which will overwrite any previously-installed EXIT
# trap by the caller; if the caller needs to combine this with their own EXIT trap, they must
# capture this helper's trap via `trap -p EXIT` and chain it manually.
# @arg $1 variable name to receive the temp file path (nameref)
function files::create_temp() {
  args::check_exactly_1_arg "$@"
  local -n _files_create_temp_var="$1"
  local _files_create_temp_path
  _files_create_temp_path="$(mktemp)"
  _files_create_temp_var="${_files_create_temp_path}"
  _FILES_CREATE_TEMP_PATHS+=("${_files_create_temp_path}")
  if [[ "${_FILES_CREATE_TEMP_TRAP_INSTALLED}" == 'n' ]]; then
    trap _files::create_temp_cleanup EXIT
    _FILES_CREATE_TEMP_TRAP_INSTALLED='y'
  fi
}

# @description Print the SHA-256 hash of a file, or '0' if the file does not exist.
# Output: stdout — hex SHA-256 digest, or '0' if file is absent
# @arg $1 file path
function files::hash() {
  args::check_exactly_1_arg "$@"
  local -r file="$1"
  if files::exists "${file}"; then
    sha256sum "${file}" | cut --delimiter=' ' --fields=1
  else
    printf '%s\n' '0'
  fi
}
