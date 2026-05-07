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
  if ! files::exists "$1"; then
    log::die "$1 does not exist"
  fi
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
  files::assert_exists "$1"
  printf '%s\n' "scale=2; $(stat --format='%s' "$1") / 1073741824" | bc
}

# Move a file, prompting if the destination already exists; skips if source and dest are byte-identical.
# $1 = source file path
# $2 = destination file path
function files::move() {
  args::check_exactly_2_args "$@"
  files::assert_exists "$1"
  if [[ "$1" == "$2" ]]; then
    log::die "File paths are the same"
  fi
  if files::exists "$2"; then
    if cmp --silent "$1" "$2"; then
      rm --force -- "$1"
      return 0
    else
      diff --color --unified "$2" "$1" || true
      if ! prompt::yn "$2 exists - Overwrite: $1 -> $2?"; then
        return 0
      fi
    fi
  else
    if ! prompt::yn "Move $1 -> $2?"; then
      return 0
    fi
  fi
  log::log "Moving: $1 -> $2"
  dirs::create "$(dirname "$2")"
  mv -- "$1" "$2"
  log::log "Moved: $1 -> $2"
}

# Move a file as root, prompting if the destination already exists; skips if byte-identical.
# $1 = source file path
# $2 = destination file path
function files::root_move() {
  args::check_exactly_2_args "$@"
  files::assert_exists "$1"
  if [[ "$1" == "$2" ]]; then
    log::die "File paths are the same"
  fi
  if sudo test -f "$2"; then
    if sudo cmp --silent "$1" "$2"; then
      sudo rm --force -- "$1"
      return 0
    else
      sudo diff --color --unified "$2" "$1" || true
      if ! prompt::yn "$2 exists - Overwrite: $1 -> $2?"; then
        return 0
      fi
    fi
  else
    if ! prompt::yn "Move $1 -> $2?"; then
      return 0
    fi
  fi
  log::log "Moving: $1 -> $2"
  dirs::root_create "$(dirname "$2")"
  sudo mv -- "$1" "$2"
  log::log "Moved: $1 -> $2"
}

# Copy a file, prompting if the destination already exists; skips if byte-identical.
# $1 = source file path
# $2 = destination file path
function files::copy() {
  args::check_exactly_2_args "$@"
  files::assert_exists "$1"
  if [[ "$1" == "$2" ]]; then
    log::die "File paths are the same"
  fi
  if files::exists "$2"; then
    if cmp --silent "$1" "$2"; then
      return 0
    else
      diff --color --unified "$2" "$1" || true
      if ! prompt::yn "$2 exists - Overwrite: $1 -> $2?"; then
        return 0
      fi
    fi
  else
    if ! prompt::yn "Copy $1 -> $2?"; then
      return 0
    fi
  fi
  log::log "Copying: $1 -> $2"
  dirs::create "$(dirname "$2")"
  cp "$1" "$2"
  log::log "Copied: $1 -> $2"
}

# Copy a file as root, prompting if the destination already exists; skips if byte-identical.
# $1 = source file path
# $2 = destination file path
function files::root_copy() {
  args::check_exactly_2_args "$@"
  files::assert_exists "$1"
  if [[ "$1" == "$2" ]]; then
    log::die "File paths are the same"
  fi
  if sudo test -f "$2"; then
    if sudo cmp --silent "$1" "$2"; then
      return 0
    else
      sudo diff --color --unified "$2" "$1" || true
      if ! prompt::yn "$2 exists - Overwrite: $1 -> $2?"; then
        return 0
      fi
    fi
  else
    if ! prompt::yn "Copy $1 -> $2?"; then
      return 0
    fi
  fi
  log::log "Copying: $1 -> $2"
  dirs::root_create "$(dirname "$2")"
  sudo cp "$1" "$2"
  log::log "Copied: $1 -> $2"
}

# Write content to a file, prompting if the file already exists; skips if content is identical.
# $1 = file path
# $2 = content to write
function files::write() {
  args::check_exactly_2_args "$@"
  if files::exists "$1"; then
    if [[ "$(cat "$1")" == "$2" ]]; then
      return 0
    else
      diff --color --unified "$1" - <<< "$2" || true
      if ! prompt::yn "$1 exists - Overwrite?"; then
        return 0
      fi
    fi
  fi
  log::log "Writing $1"
  dirs::create "$(dirname "$1")"
  printf '%s\n' "$2" > "$1"
  log::log "Wrote $1"
}

# Write content to a root-owned file, prompting if the file already exists; skips if content is identical.
# $1 = file path
# $2 = content to write
function files::root_write() {
  args::check_exactly_2_args "$@"
  if files::exists "$1"; then
    if [[ "$(sudo cat "$1")" == "$2" ]]; then
      return 0
    else
      sudo diff --color --unified "$1" - <<< "$2" || true
      if ! prompt::yn "$1 exists - Overwrite?"; then
        return 0
      fi
    fi
  fi
  log::log "Writing $1"
  dirs::root_create "$(dirname "$1")"
  printf '%s\n' "$2" | sudo tee "$1" > '/dev/null'
  log::log "Wrote $1"
}

# Append content to a file, creating the file and any missing parent directories as needed.
# $1 = file path
# $2 = content to append
function files::append_to() {
  args::check_exactly_2_args "$@"
  log::log "Appending to $1"
  dirs::create "$(dirname "$1")"
  printf '%s\n' "$2" >> "$1"
  log::log "Appended to $1"
}

# Append content to a root-owned file, creating the file and any missing parent directories as needed.
# $1 = file path
# $2 = content to append
function files::root_append_to() {
  args::check_exactly_2_args "$@"
  log::log "Appending to $1"
  dirs::root_create "$(dirname "$1")"
  printf '%s\n' "$2" | sudo tee --append "$1" > '/dev/null'
  log::log "Appended to $1"
}

# Print the SHA-256 hash of a file, or '0' if the file does not exist.
# $1 = file path
# Output: stdout — hex SHA-256 digest, or '0' if file is absent
function files::hash() {
  args::check_exactly_1_arg "$@"
  if files::exists "$1"; then
    sha256sum "$1" | cut --delimiter=' ' --fields=1
  else
    printf '%s\n' '0'
  fi
}
