#!/usr/bin/env bash

function log::log() {
  printf '\033[0;32m[%s %s] %s\033[0m\n' "$(date +%T)" "${0##*/}" "$*" >&2
}

function log::with_date() {
  printf '\033[0;32m[%s %s] %s\033[0m\n' "$(date '+%Y-%m-%d %T')" "${0##*/}" "$*" >&2
}

function log::warn() {
  printf '\033[0;33m[%s %s] WARN: %s\033[0m\n' "$(date +%T)" "${0##*/}" "$*" >&2
}

function log::die() {
  printf '\033[0;31mDIE: %s (at %s:%s line %s)\033[0m\n' "$*" "${BASH_SOURCE[1]}" "${FUNCNAME[1]}" "${BASH_LINENO[0]}" >&2
  exit 1
}

function log::_err_trap_handler() {
  args::check_exactly_3_args "$@"
  local -r exit_code="$1"
  local -r line_no="$2"
  local -r cmd="$3"
  printf '\033[0;31m[%s %s] ERROR: line %s (exit %s): %s\033[0m\n' "$(date +%T)" "${0##*/}" "${line_no}" "${exit_code}" "${cmd}" >&2
}

function log::enable_err_trap() {
  args::check_no_args "$@"
  trap 'log::_err_trap_handler "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
}
