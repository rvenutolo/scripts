#!/usr/bin/env bash

# Return true if the given path exists and is a symbolic link.
# $1 = symlink path
function symlinks::exists() {
  args::check_exactly_1_arg "$@"
  [[ -L "$1" ]]
}

# Print the target of a symbolic link; dies if the symlink does not exist.
# $1 = symlink path
# Output: stdout — symlink target path
function symlinks::get_target() {
  args::check_exactly_1_arg "$@"
  local -r symlink="$1"
  if ! symlinks::exists "${symlink}"; then
    log::die "Symbolic link does not exist: ${symlink}"
  fi
  readlink "${symlink}"
}

# Create a symbolic link from a file to a link path, prompting if the destination already exists.
# No-ops if the link already points to the correct target.
# $1 = target file path
# $2 = link path to create
function symlinks::link_file() {
  args::check_exactly_2_args "$@"
  local -r target="$1"
  local -r link="$2"
  files::assert_exists "${target}"
  if [[ -L "${link}" && "$(readlink --canonicalize "${link}")" == "$(readlink --canonicalize "${target}")" ]]; then
    return 0
  fi
  if files::exists "${link}"; then
    diff --color --unified "${link}" "${target}" || true
    if ! prompt::yn "${link} exists - Link: ${target} -> ${link}?"; then
      return 0
    fi
  else
    if ! prompt::yn "Link: ${target} -> ${link}?"; then
      return 0
    fi
  fi
  log::log "Linking: ${target} -> ${link}"
  dirs::create "$(dirname "${link}")"
  ln --symbolic --force --no-target-directory "${target}" "${link}"
  log::log "Linked: ${target} -> ${link}"
}

# Create a symbolic link from a directory to a link path, prompting if the destination already exists.
# No-ops if the link already points to the correct target.
# $1 = target directory path
# $2 = link path to create
function symlinks::link_dir() {
  args::check_exactly_2_args "$@"
  local -r target="$1"
  local -r link="$2"
  dirs::assert_exists "${target}"
  if [[ -L "${link}" && "$(readlink --canonicalize "${link}")" == "$(readlink --canonicalize "${target}")" ]]; then
    return 0
  fi
  if dirs::exists "${link}"; then
    if ! prompt::yn "${link} exists - Link: ${target} -> ${link}?"; then
      return 0
    fi
  else
    if ! prompt::yn "Link: ${target} -> ${link}?"; then
      return 0
    fi
  fi
  log::log "Linking: ${target} -> ${link}"
  dirs::create "$(dirname "${link}")"
  ln --symbolic --force --no-target-directory "${target}" "${link}"
  log::log "Linked: ${target} -> ${link}"
}
