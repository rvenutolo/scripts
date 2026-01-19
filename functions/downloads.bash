#!/usr/bin/env bash

# $1 = url
function download_and_cat() {
  check_exactly_1_arg "$@"
  local temp_file
  temp_file="$(mktemp)" || exit 1
  readonly temp_file
  download "$1" "${temp_file}"
  cat "${temp_file}"
}

# $1 = url
function download_to_temp_file() {
  check_exactly_1_arg "$@"
  local temp_file
  temp_file="$(mktemp)" || exit 1
  readonly temp_file
  download "$1" "${temp_file}"
  echo "${temp_file}"
}

# $1 = script url
# $2+ args to pass to the script
function download_and_run_script() {
  check_at_least_1_arg "$@"
  local temp_file
  temp_file="$(mktemp)" || exit 1
  readonly temp_file
  download "$1" "${temp_file}"
  chmod +x "${temp_file}"
  shift
  "${temp_file}" "$@"
}

# $1 = script url
# $2+ args to pass to the script
function download_and_run_script_as_root() {
  check_at_least_1_arg "$@"
  local temp_file
  temp_file="$(mktemp)" || exit 1
  readonly temp_file
  download "$1" "${temp_file}"
  chmod +x "${temp_file}"
  shift
  sudo "${temp_file}" "$@"
}
