#!/usr/bin/env bash

# @description Print a green timestamped info message to stderr, prefixed with the script name.
# @arg $@ message text
function log::log() {
  printf '\033[0;32m[%s %s] %s\033[0m\n' "$(date +%T)" "${0##*/}" "$*" >&2
}

# @description Print a green timestamped info message (with full date) to stderr, prefixed with the script name.
# @arg $@ message text
function log::with_date() {
  printf '\033[0;32m[%s %s] %s\033[0m\n' "$(date '+%Y-%m-%d %T')" "${0##*/}" "$*" >&2
}

# @description Print a yellow timestamped warning message to stderr, prefixed with the script name.
# @arg $@ message text
function log::warn() {
  printf '\033[0;33m[%s %s] WARN: %s\033[0m\n' "$(date +%T)" "${0##*/}" "$*" >&2
}

# @description Print a red error message with caller context to stderr and exit with status 1.
# @arg $@ message text
function log::die() {
  printf '\033[0;31mDIE: %s (at %s:%s line %s)\033[0m\n' \
    "$*" "${BASH_SOURCE[1]}" "${FUNCNAME[1]}" "${BASH_LINENO[0]}" >&2
  exit 1
}

# @description Print a red timestamped ERROR line to stderr; intended for use as an ERR trap handler.
# @arg $1 exit code of the failing command
# @arg $2 line number where the error occurred
# @arg $3 the failing command string (BASH_COMMAND)
function log::_err_trap_handler() {
  args::check_exactly_3_args "$@"
  local -r exit_code="$1"
  local -r line_no="$2"
  local -r cmd="$3"
  printf '\033[0;31m[%s %s] ERROR: line %s (exit %s): %s\033[0m\n' \
    "$(date +%T)" "${0##*/}" "${line_no}" "${exit_code}" "${cmd}" >&2
}

# @description Install an ERR trap that prints a red error line via log::_err_trap_handler on any unhandled failure.
# @noargs
function log::enable_err_trap() {
  args::check_no_args "$@"
  trap 'log::_err_trap_handler "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
}
