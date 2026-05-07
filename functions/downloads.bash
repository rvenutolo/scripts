#!/usr/bin/env bash

# Download a URL to a temp file and print its contents to stdout.
# $1 = url
# Output: stdout — file contents
function downloads::download_and_cat() {
  args::check_exactly_1_arg "$@"
  local temp_file
  temp_file="$(mktemp)"
  readonly temp_file
  trap 'rm --force -- "${temp_file}"' EXIT
  download "$1" "${temp_file}"
  cat "${temp_file}"
}

# Download a URL to a temp file and print the temp file path to stdout.
# $1 = url
# Output: stdout — path to the temp file containing the downloaded content
function downloads::download_to_temp_file() {
  args::check_exactly_1_arg "$@"
  local temp_file
  temp_file="$(mktemp)"
  readonly temp_file
  trap 'rm --force -- "${temp_file}"' EXIT
  download "$1" "${temp_file}"
  printf '%s\n' "${temp_file}"
}

# Download a script from a URL, make it executable, and run it with any extra arguments.
# $1 = script url
# $2+ = arguments to pass to the script
function downloads::download_and_run_script() {
  args::check_at_least_1_arg "$@"
  local -r url="$1"
  local temp_file
  temp_file="$(mktemp)"
  readonly temp_file
  trap 'rm --force -- "${temp_file}"' EXIT
  download "${url}" "${temp_file}"
  chmod +x "${temp_file}"
  shift
  "${temp_file}" "$@"
}

# Download a script from a URL, make it executable, and run it as root with any extra arguments.
# $1 = script url
# $2+ = arguments to pass to the script
function downloads::download_and_run_script_as_root() {
  args::check_at_least_1_arg "$@"
  local -r url="$1"
  local temp_file
  temp_file="$(mktemp)"
  readonly temp_file
  trap 'rm --force -- "${temp_file}"' EXIT
  download "${url}" "${temp_file}"
  chmod +x "${temp_file}"
  shift
  sudo "${temp_file}" "$@"
}
