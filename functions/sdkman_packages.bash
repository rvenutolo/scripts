#!/usr/bin/env bash

# Install the latest version of an SDKMAN package.
# $1 = package name (e.g. "gradle")
function sdkman_packages::install_sdkman_package() {
  args::check_exactly_1_arg "$@"
  sdk install "$1" | sdkman::clean_output
}

# Uninstall a specific version of an SDKMAN package.
# $1 = package name (e.g. "gradle")
# $2 = version string to uninstall
function sdkman_packages::uninstall_package_version() {
  args::check_exactly_2_args "$@"
  sdk uninstall "$1" "$2" | sdkman::clean_output
}

# Install the latest version of every SDKMAN package listed for this machine.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
function sdkman_packages::install_sdkman_packages() {
  args::check_no_args "$@"
  while read -r pkg; do
    sdkman_packages::install_sdkman_package "${pkg}"
  done < <(packages::get_sdkman)
}

# Print the names of all installed SDKMAN packages (excluding java).
# Output: stdout — package names, one per line, sorted
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
function sdkman_packages::get_installed_packages() {
  args::check_no_args "$@"
  find "${SDKMAN_CANDIDATES_DIR}" -maxdepth '1' -mindepth '1' -type 'd' ! -name 'java' -printf '%f\n' | sort
}

# Print all installed version strings for the given SDKMAN package.
# $1 = package name
# Output: stdout — version strings, one per line, sorted
function sdkman_packages::get_installed_packages_versions() {
  args::check_exactly_1_arg "$@"
  find "${SDKMAN_CANDIDATES_DIR}/$1" -maxdepth '1' -mindepth '1' -type 'd' -printf '%f\n' | sort
}

# Print the currently active version of the given SDKMAN package (via the 'current' symlink target).
# $1 = package name
# Output: stdout — active version string
function sdkman_packages::get_current_package_version() {
  args::check_exactly_1_arg "$@"
  symlinks::get_target "${SDKMAN_CANDIDATES_DIR}/$1/current"
}

# Uninstall all versions of an SDKMAN package except the currently active one.
# $1 = package name
function sdkman_packages::prune_sdkman_package() {
  args::check_exactly_1_arg "$@"
  local current_version
  current_version="$(sdkman_packages::get_current_package_version "$1")"
  readonly current_version
  while read -r version; do
    if [[ "${version}" != "${current_version}" ]]; then
      sdkman_packages::uninstall_package_version "$1" "${version}"
    fi
  done < <(sdkman_packages::get_installed_packages_versions "$1")
}

# Uninstall all outdated versions of every installed SDKMAN package (excluding java).
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
function sdkman_packages::prune_sdkman_packages() {
  args::check_no_args "$@"
  while read -r package; do
    sdkman_packages::prune_sdkman_package "${package}"
  done < <(sdkman_packages::get_installed_packages)
}
