#!/usr/bin/env bash

# Return true if the given path exists and is a regular file.
# $1 = file path
function files::exists() {
  args::check_exactly_1_arg "$@"
  [[ -f "$1" ]]
}

# Die if the given file does not exist.
# $1 = file path
function files::assert_exists() {
  args::check_exactly_1_arg "$@"
  local -r file="$1"
  if ! files::exists "${file}"; then
    log::die "${file} does not exist"
  fi
}

# Return true if the given path exists as any filesystem entry (regular file, directory, symlink, device, etc.).
# $1 = path to test
function files::any_exists() {
  args::check_exactly_1_arg "$@"
  [[ -e "$1" ]]
}

# Return true if the given file exists and is readable.
# $1 = file path
function files::is_readable() {
  args::check_exactly_1_arg "$@"
  [[ -r "$1" ]]
}

# Print the size of a file in gigabytes (two decimal places).
# $1 = file path
# Output: stdout — size in GB, e.g. "1.23"
function files::size_gb() {
  args::check_exactly_1_arg "$@"
  local -r file="$1"
  files::assert_exists "${file}"
  printf '%s\n' "scale=2; $(stat --format='%s' "${file}") / 1073741824" | bc
}

# Move a file, prompting if the destination already exists; skips if source and dest are byte-identical.
# $1 = source file path
# $2 = destination file path
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

# Move a file quietly, prompting if the destination already exists; skips if source and dest are byte-identical.
# Like files::move but suppresses the "Moving/Moved" log messages.
# $1 = source file path
# $2 = destination file path
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

# Move a file without prompting, overwriting destination if it exists. For programmatic temp-file-to-dest moves
# where interactive confirmation would be inappropriate. Creates parent directory of destination if needed.
# $1 = source file path
# $2 = destination file path
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

# Move a file quietly without prompting, overwriting destination if it exists. Creates parent directory of
# destination if needed. Like files::move_no_prompt but suppresses the "Moving/Moved" log messages.
# $1 = source file path
# $2 = destination file path
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

# Move a file as root, prompting if the destination already exists; skips if byte-identical.
# $1 = source file path
# $2 = destination file path
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

# Move a file as root quietly, prompting if the destination already exists; skips if byte-identical.
# Like files::root_move but suppresses the "Moving/Moved" log messages.
# $1 = source file path
# $2 = destination file path
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

# Copy a file, prompting if the destination already exists; skips if byte-identical.
# $1 = source file path
# $2 = destination file path
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

# Copy a file quietly, prompting if the destination already exists; skips if byte-identical.
# Like files::copy but suppresses the "Copying/Copied" log messages.
# $1 = source file path
# $2 = destination file path
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

# Copy a file as root, prompting if the destination already exists; skips if byte-identical.
# $1 = source file path
# $2 = destination file path
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

# Copy a file as root quietly, prompting if the destination already exists; skips if byte-identical.
# Like files::root_copy but suppresses the "Copying/Copied" log messages.
# $1 = source file path
# $2 = destination file path
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

# Write content to a file, prompting if the file already exists; skips if content is identical.
# $1 = file path
# $2 = content to write
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

# Write content to a file quietly, prompting if the file already exists; skips if content is identical.
# Like files::write but suppresses the "Writing/Wrote" log messages.
# $1 = file path
# $2 = content to write
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

# Write content to a root-owned file, prompting if the file already exists; skips if content is identical.
# $1 = file path
# $2 = content to write
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

# Write content to a root-owned file quietly, prompting if the file already exists; skips if content is identical.
# Like files::root_write but suppresses the "Writing/Wrote" log messages.
# $1 = file path
# $2 = content to write
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

# Append content to a file, creating the file and any missing parent directories as needed.
# $1 = file path
# $2 = content to append
function files::append_to() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r content="$2"
  log::log "Appending to ${file}"
  dirs::create "$(dirname "${file}")"
  printf '%s\n' "${content}" >> "${file}"
  log::log "Appended to ${file}"
}

# Append content to a file quietly, creating the file and any missing parent directories as needed.
# Like files::append_to but suppresses the "Appending/Appended" log messages.
# $1 = file path
# $2 = content to append
function files::append_to_quiet() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r content="$2"
  dirs::create "$(dirname "${file}")"
  printf '%s\n' "${content}" >> "${file}"
}

# Append content to a root-owned file, creating the file and any missing parent directories as needed.
# $1 = file path
# $2 = content to append
function files::root_append_to() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r content="$2"
  log::log "Appending to ${file}"
  dirs::root_create "$(dirname "${file}")"
  printf '%s\n' "${content}" | sudo tee --append "${file}" > '/dev/null'
  log::log "Appended to ${file}"
}

# Append content to a root-owned file quietly, creating the file and any missing parent directories as needed.
# Like files::root_append_to but suppresses the "Appending/Appended" log messages.
# $1 = file path
# $2 = content to append
function files::root_append_to_quiet() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r content="$2"
  dirs::root_create "$(dirname "${file}")"
  printf '%s\n' "${content}" | sudo tee --append "${file}" > '/dev/null'
}

# Print the SHA-256 hash of a file, or '0' if the file does not exist.
# $1 = file path
# Output: stdout — hex SHA-256 digest, or '0' if file is absent
function files::hash() {
  args::check_exactly_1_arg "$@"
  local -r file="$1"
  if files::exists "${file}"; then
    sha256sum "${file}" | cut --delimiter=' ' --fields=1
  else
    printf '%s\n' '0'
  fi
}
