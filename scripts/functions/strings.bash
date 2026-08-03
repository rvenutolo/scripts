#!/usr/bin/env bash

# @description Return true if the string is empty (zero length).
# @arg $1 string to test
# @exitcode 0 if true
# @exitcode 1 if false
function strings::is_empty() {
  args::check_exactly_1_arg "$@"
  [[ -z "$1" ]]
}

# @description Return true if the string is non-empty (at least one character).
# @arg $1 string to test
# @exitcode 0 if true
# @exitcode 1 if false
function strings::is_not_empty() {
  args::check_exactly_1_arg "$@"
  [[ -n "$1" ]]
}

# @description Return true if the string is empty or contains only whitespace characters.
# @arg $1 string to test
# @exitcode 0 if true
# @exitcode 1 if false
function strings::is_blank() {
  args::check_exactly_1_arg "$@"
  [[ -z "${1//[[:space:]]/}" ]]
}

# @description Return true if the string contains at least one non-whitespace character.
# @arg $1 string to test
# @exitcode 0 if true
# @exitcode 1 if false
function strings::is_not_blank() {
  args::check_exactly_1_arg "$@"
  [[ -n "${1//[[:space:]]/}" ]]
}

# @description Die if the string is not empty (zero length).
# @arg $1 string to test
function strings::assert_empty() {
  args::check_exactly_1_arg "$@"
  if ! strings::is_empty "$1"; then
    log::die "Expected empty string, got: $1"
  fi
}

# @description Die if the string is empty (zero length).
# @arg $1 string to test
function strings::assert_not_empty() {
  args::check_exactly_1_arg "$@"
  if ! strings::is_not_empty "$1"; then
    log::die "Expected non-empty string"
  fi
}

# @description Die if the string contains any non-whitespace characters.
# @arg $1 string to test
function strings::assert_blank() {
  args::check_exactly_1_arg "$@"
  if ! strings::is_blank "$1"; then
    log::die "Expected blank string, got: $1"
  fi
}

# @description Die if the string is empty or contains only whitespace characters.
# @arg $1 string to test
function strings::assert_not_blank() {
  args::check_exactly_1_arg "$@"
  if ! strings::is_not_blank "$1"; then
    log::die "Expected non-blank string"
  fi
}

# @description Print the string with leading and trailing whitespace removed.
# Output: stdout — trimmed string
# @arg $1 string
function strings::trim() {
  args::check_exactly_1_arg "$@"
  local trimmed="$1"
  trimmed="${trimmed#"${trimmed%%[![:space:]]*}"}"
  trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
  printf '%s\n' "${trimmed}"
}

# @description Print the string with a trailing slash appended if it does not already end with one.
# Output: stdout — string guaranteed to end with '/'
# @arg $1 string
function strings::ensure_trailing_slash() {
  args::check_exactly_1_arg "$@"
  local -r str="$1"
  if strings::is_not_empty "${str}"; then
    case "${str}" in
      */) printf '%s\n' "${str}" ;;
      *) printf '%s\n' "${str}/" ;;
    esac
  else
    printf '%s\n' "${str}"
  fi
}
