#!/usr/bin/env bash

# $1 = url
function downloads::download_and_cat() {
  args::check_exactly_1_arg "$@"
  local temp_file
  temp_file="$(mktemp)"
  readonly temp_file
  download "$1" "${temp_file}"
  cat "${temp_file}"
}

# $1 = url
function downloads::download_to_temp_file() {
  args::check_exactly_1_arg "$@"
  local temp_file
  temp_file="$(mktemp)"
  readonly temp_file
  download "$1" "${temp_file}"
  printf '%s\n' "${temp_file}"
}

# $1 = script url
# $2+ args to pass to the script
function downloads::download_and_run_script() {
  args::check_at_least_1_arg "$@"
  local temp_file
  temp_file="$(mktemp)"
  readonly temp_file
  download "$1" "${temp_file}"
  chmod +x "${temp_file}"
  shift
  "${temp_file}" "$@"
}

# $1 = script url
# $2+ args to pass to the script
function downloads::download_and_run_script_as_root() {
  args::check_at_least_1_arg "$@"
  local temp_file
  temp_file="$(mktemp)"
  readonly temp_file
  download "$1" "${temp_file}"
  chmod +x "${temp_file}"
  shift
  sudo "${temp_file}" "$@"
}
