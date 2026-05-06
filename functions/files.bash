#!/usr/bin/env bash

# $1 = file
function files::exists() {
  args::check_exactly_1_arg "$@"
  [[ -f "$1" ]]
}

# $1 = file
function files::assert_exists() {
  args::check_exactly_1_arg "$@"
  if ! files::exists "$1"; then
    log::die "$1 does not exist"
  fi
}

# $1 = file
function files::is_readable() {
  args::check_exactly_1_arg "$@"
  [[ -r "$1" ]]
}

# $1 = file
function files::size_gb() {
  args::check_exactly_1_arg "$@"
  files::assert_exists "$1"
  printf '%s\n' "scale=2; $(stat --format='%s' "$1") / 1073741824" | bc
}

# $1 = old file location
# $2 = new file location
function files::move() {
  args::check_exactly_2_args "$@"
  files::assert_exists "$1"
  if [[ "$1" == "$2" ]]; then
    log::die "File paths are the same"
  fi
  if files::exists "$2"; then
    if cmp --silent "$1" "$2"; then
      rm "$1"
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
  mv "$1" "$2"
  log::log "Moved: $1 -> $2"
}

# $1 = old file location
# $2 = new file location
function files::root_move() {
  args::check_exactly_2_args "$@"
  files::assert_exists "$1"
  if [[ "$1" == "$2" ]]; then
    log::die "File paths are the same"
  fi
  if sudo test -f "$2"; then
    if sudo cmp --silent "$1" "$2"; then
      sudo rm "$1"
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
  sudo mv "$1" "$2"
  log::log "Moved: $1 -> $2"
}

# $1 = old file location
# $2 = new file location
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

# $1 = source file
# $2 = destination file
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

# $1 = file
# $2 = content
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
  printf '%s\n' "${2:-}" > "$1"
  log::log "Wrote $1"
}

# $1 = file
# $2 = content
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

# $1 = file
# $2 = content
function files::append_to() {
  args::check_exactly_2_args "$@"
  log::log "Appending to $1"
  dirs::create "$(dirname "$1")"
  printf '%s\n' "${2:-}" >> "$1"
  log::log "Appended to $1"
}

# $1 = file
# $2 = content
function files::root_append_to() {
  args::check_exactly_2_args "$@"
  log::log "Appending to $1"
  dirs::root_create "$(dirname "$1")"
  printf '%s\n' "$2" | sudo tee --append "$1" > '/dev/null'
  log::log "Appended to $1"
}

# $1 = file
function files::hash() {
  if files::exists "$1"; then
    sha256sum "$1" | cut --delimiter=' ' --fields=1
  else
    printf '%s\n' '0'
  fi
}
