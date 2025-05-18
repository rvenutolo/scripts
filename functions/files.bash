#!/usr/bin/env bash

# $1 = file
function file_exists() {
  check_exactly_1_arg "$@"
  [[ -f "$1" ]]
}

# $1 = file
function assert_file_exists() {
  check_exactly_1_arg "$@"
  if ! file_exists "$1"; then
    die "$1 does not exist"
  fi
}

# $1 = file
function is_readable_file() {
  check_exactly_1_arg "$@"
  [[ -r "$1" ]]
}

# $1 = file
function file_size_gb() {
  check_exactly_1_arg "$@"
  assert_file_exists "$1"
  echo "scale=2; $(stat --format='%s' "$1") / 1073741824" | bc
}

# $1 = target file
# $2 = link file
function link_file() {
  check_exactly_2_args "$@"
  assert_file_exists "$1"
  if [[ -L "$2" && "$(readlink --canonicalize "$2")" == "$(readlink --canonicalize "$1")" ]]; then
    return 0
  fi
  if file_exists "$2"; then
    diff --color --unified "$2" "$1" || true
    if ! prompt_yn "$2 exists - Link: $1 -> $2?"; then
      return 0
    fi
  else
    if ! prompt_yn "Link: $1 -> $2?"; then
      return 0
    fi
  fi
  log "Linking: $1 -> $2"
  create_dir "$(dirname "$2")"
  ln --symbolic --force "$1" "$2"
  log "Linked: $1 -> $2"
}

# $1 = old file location
# $2 = new file location
function move_file() {
  check_exactly_2_args "$@"
  assert_file_exists "$1"
  if [[ "$1" == "$2" ]]; then
    die "File paths are the same"
  fi
  if file_exists "$2"; then
    if cmp --silent "$1" "$2"; then
      rm "$1"
      return 0
    else
      diff --color --unified "$2" "$1" || true
      if ! prompt_yn "$2 exists - Overwrite: $1 -> $2?"; then
        return 0
      fi
    fi
  else
    if ! prompt_yn "Move $1 -> $2?"; then
      return 0
    fi
  fi
  log "Moving: $1 -> $2"
  create_dir "$(dirname "$2")"
  mv "$1" "$2"
  log "Moved: $1 -> $2"
}

# $1 = old file location
# $2 = new file location
function root_move_file() {
  check_exactly_2_args "$@"
  assert_file_exists "$1"
  if [[ "$1" == "$2" ]]; then
    die "File paths are the same"
  fi
  if sudo bash -c "[[ -f $2 ]]"; then
    if sudo cmp --silent "$1" "$2"; then
      sudo rm "$1"
      return 0
    else
      sudo diff --color --unified "$2" "$1" || true
      if ! prompt_yn "$2 exists - Overwrite: $1 -> $2?"; then
        return 0
      fi
    fi
  else
    if ! prompt_yn "Move $1 -> $2?"; then
      return 0
    fi
  fi
  log "Moving: $1 -> $2"
  root_create_dir "$(dirname "$2")"
  sudo mv "$1" "$2"
  log "Moved: $1 -> $2"
}

# $1 = old file location
# $2 = new file location
function copy_file() {
  check_exactly_2_args "$@"
  assert_file_exists "$1"
  if [[ "$1" == "$2" ]]; then
    die "File paths are the same"
  fi
  if file_exists "$2"; then
    if cmp --silent "$1" "$2"; then
      return 0
    else
      diff --color --unified "$2" "$1" || true
      if ! prompt_yn "$2 exists - Overwrite: $1 -> $2?"; then
        return 0
      fi
    fi
  else
    if ! prompt_yn "Copy $1 -> $2?"; then
      return 0
    fi
  fi
  log "Copying: $1 -> $2"
  create_dir "$(dirname "$2")"
  cp "$1" "$2"
  log "Copied: $1 -> $2"
}

# $1 = source file
# $2 = destination file
function root_copy_file() {
  check_exactly_2_args "$@"
  assert_file_exists "$1"
  if [[ "$1" == "$2" ]]; then
    die "File paths are the same"
  fi
  if sudo bash -c "[[ -f $2 ]]"; then
    if sudo cmp --silent "$1" "$2"; then
      return 0
    else
      sudo diff --color --unified "$2" "$1" || true
      if ! prompt_yn "$2 exists - Overwrite: $1 -> $2?"; then
        return 0
      fi
    fi
  else
    if ! prompt_yn "Copy $1 -> $2?"; then
      return 0
    fi
  fi
  log "Copying: $1 -> $2"
  root_create_dir "$(dirname "$2")"
  sudo cp "$1" "$2"
  log "Copied: $1 -> $2"
}

# $1 = file
# $2 = content
function write_file() {
  check_exactly_2_args "$@"
  if file_exists "$1"; then
    if [[ "$(cat "$1")" == "$2" ]]; then
      return 0
    else
      diff --color --unified "$1" - <<< "$2" || true
      if ! prompt_yn "$1 exists - Overwrite?"; then
        return 0
      fi
    fi
  fi
  log "Writing $1"
  create_dir "$(dirname "$1")"
  echo "${2:-}" > "$1"
  log "Wrote $1"
}

# $1 = file
# $2 = content
function root_write_file() {
  check_exactly_2_args "$@"
  if file_exists "$1"; then
    if [[ "$(sudo cat "$1")" == "$2" ]]; then
      return 0
    else
      sudo diff --color --unified "$1" - <<< "$2" || true
      if ! prompt_yn "$1 exists - Overwrite?"; then
        return 0
      fi
    fi
  fi
  log "Writing $1"
  root_create_dir "$(dirname "$1")"
  echo "$2" | sudo tee "$1" > '/dev/null'
  log "Wrote $1"
}

# $1 = file
# $2 = content
function append_to_file() {
  check_exactly_2_args "$@"
  log "Appending to $1"
  create_dir "$(dirname "$1")"
  echo "${2:-}" >> "$1"
  log "Appended to $1"
}

# $1 = file
# $2 = content
function root_append_to_file() {
  check_exactly_2_args "$@"
  log "Appending to $1"
  root_create_dir "$(dirname "$1")"
  echo "$2" | sudo tee --append "$1" > '/dev/null'
  log "Appended to $1"
}

# $1 = file
function file_hash() {
  sha256sum "${1}" | cut --delimiter=' ' --fields='1'
}
