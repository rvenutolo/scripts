#!/usr/bin/env bash

function log() {
  printf '\033[0;32m[%s %s] %s\033[0m\n' "$(date +%T)" "${0##*/}" "$*" >&2
}

function log_with_date() {
  printf '\033[0;32m[%s %s] %s\033[0m\n' "$(date '+%Y-%m-%d %T')" "${0##*/}" "$*" >&2
}

function log_warn() {
  printf '\033[0;33m[%s %s] WARN: %s\033[0m\n' "$(date +%T)" "${0##*/}" "$*" >&2
}

function die() {
  printf '\033[0;31mDIE: %s (at %s:%s line %s)\033[0m\n' "$*" "${BASH_SOURCE[1]}" "${FUNCNAME[1]}" "${BASH_LINENO[0]}" >&2
  exit 1
}
