#!/usr/bin/env bash

# These functions intentionally mutate the caller's PATH (they do NOT scope mutations to a subshell).
# Callers that want PATH changes confined to a block must wrap the call in their own ( ... ) subshell.

# @description Remove all occurrences of a directory from PATH.
# When PATH equals exactly the directory, clears PATH without invoking awk/sed.
# Uses awk -v (not --assign) because mawk — the default awk on Debian/Ubuntu — does
# not accept --assign. -v is POSIX and works on every awk implementation.
# @arg $1 directory path to remove
function path::remove() {
  args::check_exactly_1_arg "$@"
  local -r dir="$1"
  if [[ "${PATH}" == "${dir}" ]]; then
    # Intentional: clearing PATH is this function's explicit purpose.
    # shellcheck disable=SC2123
    PATH=''
    return
  fi
  PATH="$(
    printf '%s' "${PATH}" \
      | awk -v 'RS=:' -v 'ORS=:' -v "path=${dir}" '$0 != path' \
      | sed 's/:$//'
  )"
}

# @description Append a directory to PATH (removing any existing occurrence first to avoid duplicates).
# When PATH is empty, sets PATH to just the directory — no stray leading colon.
# @arg $1 directory path to append
function path::append() {
  args::check_exactly_1_arg "$@"
  local -r dir="$1"
  if [[ -z "${PATH}" ]]; then
    PATH="${dir}"
    return
  fi
  path::remove "${dir}"
  PATH="${PATH}:${dir}"
}

# @description Prepend a directory to PATH (removing any existing occurrence first to avoid duplicates).
# When PATH is empty, sets PATH to just the directory — no stray trailing colon.
# @arg $1 directory path to prepend
function path::prepend() {
  args::check_exactly_1_arg "$@"
  local -r dir="$1"
  if [[ -z "${PATH}" ]]; then
    PATH="${dir}"
    return
  fi
  path::remove "${dir}"
  PATH="${dir}:${PATH}"
}
