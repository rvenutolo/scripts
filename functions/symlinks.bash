#!/usr/bin/env bash

# @description Predicate: does the given symlink already point at the canonicalized target?
# True if the link exists AND its canonical resolution equals the canonical resolution of the target.
# @arg $1 link path
# @arg $2 target path
# @exitcode 0 if link points at target
# @exitcode 1 otherwise
function symlinks::points_at() {
  args::check_exactly_2_args "$@"
  local -r link="$1"
  local -r target="$2"
  [[ -L ${link} && "$(readlink --canonicalize "${link}")" == "$(readlink --canonicalize "${target}")" ]]
}

# @description Return true if the given path exists and is a symbolic link.
# @arg $1 symlink path
function symlinks::exists() {
  args::check_exactly_1_arg "$@"
  [[ -L $1 ]]
}

# @description Print the target of a symbolic link; dies if the symlink does not exist.
# Output: stdout — symlink target path
# @arg $1 symlink path
function symlinks::get_target() {
  args::check_exactly_1_arg "$@"
  local -r symlink="$1"
  if ! symlinks::exists "${symlink}"; then
    log::die "Symbolic link does not exist: ${symlink}"
  fi
  readlink "${symlink}"
}

# @description List broken (dangling) symlinks under a directory. Uses the `find -L ... -type l`
# idiom: with -L, working links resolve to their target's type and drop out, leaving only
# danglers as -type l.
# @arg $1 dir optional directory to scan (default ".")
# @stdout one broken-symlink path per line; empty if none found
function symlinks::find_broken() {
  args::check_at_most_1_arg "$@"
  local dir
  if args::no_args "$@"; then
    dir="."
  else
    dir="$1"
  fi
  # -L: no long-form equivalent; -L + -type l is the canonical broken-symlink idiom
  find -L "${dir}" -type l 2>'/dev/null' || true
}

# @description Create a symbolic link from a file to a link path, prompting if the destination already exists.
# No-ops if the link already points to the correct target.
# @arg $1 target file path
# @arg $2 link path to create
function symlinks::link_file() {
  args::check_exactly_2_args "$@"
  local -r target="$1"
  local -r link="$2"
  files::assert_exists "${target}"
  if symlinks::points_at "${link}" "${target}"; then
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

# @description Create a symbolic link from a directory to a link path, prompting if the destination already exists.
# No-ops if the link already points to the correct target.
# @arg $1 target directory path
# @arg $2 link path to create
function symlinks::link_dir() {
  args::check_exactly_2_args "$@"
  local -r target="$1"
  local -r link="$2"
  dirs::assert_exists "${target}"
  if symlinks::points_at "${link}" "${target}"; then
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
