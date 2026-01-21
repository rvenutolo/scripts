#!/usr/bin/env bash

# $1 = package
function install_sdkman_package() {
  check_exactly_1_arg "$@"
  sdk install "$1" | clean_sdkman_output
}

# $1 = package
# $2 = version
function uninstall_package_version() {
  check_exactly_2_args "$@"
  sdk uninstall "$1" "$2" | clean_sdkman_output
}

#shellcheck disable=SC2120
function install_sdkman_packages() {
  check_no_args "$@"
  get_sdkman_packages | while read -r pkg; do
    install_sdkman_package "${pkg}"
  done
}

#shellcheck disable=SC2120
function get_installed_packages() {
  check_no_args "$@"
  find "${SDKMAN_CANDIDATES_DIR}" -maxdepth '1' -mindepth '1' -type 'd' ! -name 'java' -printf '%f\n' | sort
}

# $1 = package
function get_installed_packages_versions() {
  check_exactly_1_arg "$@"
  find "${SDKMAN_CANDIDATES_DIR}/$1" -maxdepth '1' -mindepth '1' -type 'd' -printf '%f\n' | sort
}

# $1 = package
function get_current_package_version() {
  check_exactly_1_arg "$@"
  get_symlink_target "${SDKMAN_CANDIDATES_DIR}/$1/current"
}

# $1 = package
function prune_sdkman_package() {
  check_exactly_1_arg "$@"
  local current_version
  current_version="$(get_current_package_version "$1")" || exit 1
  readonly current_version
  get_installed_packages_versions "$1" | while read -r version; do
    if [[ "${version}" != "${current_version}" ]]; then
      uninstall_package_version "$1" "${version}"
    fi
  done
}

#shellcheck disable=SC2120
function prune_sdkman_packages() {
  check_no_args "$@"
  get_installed_packages | while read -r package; do
    prune_sdkman_package "${package}"
  done
}
