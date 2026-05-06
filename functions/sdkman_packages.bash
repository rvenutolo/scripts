#!/usr/bin/env bash

# $1 = package
function sdkman_packages::install_sdkman_package() {
  args::check_exactly_1_arg "$@"
  sdk install "$1" | sdkman::clean_output
}

# $1 = package
# $2 = version
function sdkman_packages::uninstall_package_version() {
  args::check_exactly_2_args "$@"
  sdk uninstall "$1" "$2" | sdkman::clean_output
}

#shellcheck disable=SC2120
function sdkman_packages::install_sdkman_packages() {
  args::check_no_args "$@"
  while read -r pkg; do
    sdkman_packages::install_sdkman_package "${pkg}"
  done < <(packages::get_sdkman)
}

#shellcheck disable=SC2120
function sdkman_packages::get_installed_packages() {
  args::check_no_args "$@"
  find "${SDKMAN_CANDIDATES_DIR}" -maxdepth '1' -mindepth '1' -type 'd' ! -name 'java' -printf '%f\n' | sort
}

# $1 = package
function sdkman_packages::get_installed_packages_versions() {
  args::check_exactly_1_arg "$@"
  find "${SDKMAN_CANDIDATES_DIR}/$1" -maxdepth '1' -mindepth '1' -type 'd' -printf '%f\n' | sort
}

# $1 = package
function sdkman_packages::get_current_package_version() {
  args::check_exactly_1_arg "$@"
  symlinks::get_target "${SDKMAN_CANDIDATES_DIR}/$1/current"
}

# $1 = package
function sdkman_packages::prune_sdkman_package() {
  args::check_exactly_1_arg "$@"
  local current_version
  current_version="$(sdkman_packages::get_current_package_version "$1")" || exit 1
  readonly current_version
  while read -r version; do
    if [[ "${version}" != "${current_version}" ]]; then
      sdkman_packages::uninstall_package_version "$1" "${version}"
    fi
  done < <(sdkman_packages::get_installed_packages_versions "$1")
}

#shellcheck disable=SC2120
function sdkman_packages::prune_sdkman_packages() {
  args::check_no_args "$@"
  while read -r package; do
    sdkman_packages::prune_sdkman_package "${package}"
  done < <(sdkman_packages::get_installed_packages)
}
