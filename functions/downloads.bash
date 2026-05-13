#!/usr/bin/env bash

# @description Download a URL to a temp file and print its contents to stdout.
# Output: stdout — file contents
# @arg $1 url
function downloads::download_and_cat() {
  args::check_exactly_1_arg "$@"
  local temp_file
  temp_file="$(mktemp)"
  readonly temp_file
  # expand temp_file at trap-set time (double quotes) — the local goes out of scope before EXIT fires
  # shellcheck disable=SC2064 # intentional immediate expansion
  trap "rm --force -- '${temp_file}'" EXIT
  download "$1" "${temp_file}"
  cat "${temp_file}"
}

# @description Download a URL to a temp file and print the temp file path to stdout.
# Output: stdout — path to the temp file containing the downloaded content
# @arg $1 url
function downloads::download_to_temp_file() {
  args::check_exactly_1_arg "$@"
  local temp_file
  temp_file="$(mktemp)"
  readonly temp_file
  # expand temp_file at trap-set time (double quotes) — the local goes out of scope before EXIT fires
  # shellcheck disable=SC2064 # intentional immediate expansion
  trap "rm --force -- '${temp_file}'" EXIT
  download "$1" "${temp_file}"
  printf '%s\n' "${temp_file}"
}

# @description Download a script from a URL, make it executable, and run it with any extra arguments.
# $2+ = arguments to pass to the script
# @arg $1 script url
function downloads::download_and_run_script() {
  args::check_at_least_1_arg "$@"
  local -r url="$1"
  local temp_file
  temp_file="$(mktemp)"
  readonly temp_file
  # expand temp_file at trap-set time (double quotes) — the local goes out of scope before EXIT fires
  # shellcheck disable=SC2064 # intentional immediate expansion
  trap "rm --force -- '${temp_file}'" EXIT
  download "${url}" "${temp_file}"
  chmod +x "${temp_file}"
  shift
  "${temp_file}" "$@"
}

# @description Download a script from a URL, make it executable, and run it as root with any extra arguments.
# $2+ = arguments to pass to the script
# @arg $1 script url
function downloads::download_and_run_script_as_root() {
  args::check_at_least_1_arg "$@"
  local -r url="$1"
  local temp_file
  temp_file="$(mktemp)"
  readonly temp_file
  # expand temp_file at trap-set time (double quotes) — the local goes out of scope before EXIT fires
  # shellcheck disable=SC2064 # intentional immediate expansion
  trap "rm --force -- '${temp_file}'" EXIT
  download "${url}" "${temp_file}"
  chmod +x "${temp_file}"
  shift
  sudo "${temp_file}" "$@"
}
