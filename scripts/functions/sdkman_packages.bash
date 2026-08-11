#!/usr/bin/env bash

# @description Install the latest version of an SDKMAN package.
#              Failure is signalled through the `sdk install | sdkman::clean_output` pipeline, so
#              the caller must have `pipefail` set for a failed install to be observable.
# @arg $1 package name (e.g. "gradle")
# @exitcode 0 sdk install succeeded
# @exitcode 1 sdk install failed (requires pipefail in the caller)
function sdkman_packages::install_sdkman_package() {
  args::check_exactly_1_arg "$@"
  sdk install "$1" | sdkman::clean_output
}

# @description Uninstall a specific version of an SDKMAN package.
# @arg $1 package name (e.g. "gradle")
# @arg $2 version string to uninstall
function sdkman_packages::uninstall_package_version() {
  args::check_exactly_2_args "$@"
  sdk uninstall "$1" "$2" | sdkman::clean_output
}

# @description Install the latest version of every SDKMAN package listed for this machine.
#              A package that fails to install is logged and skipped rather than aborting the
#              run, so one broken upstream package cannot take down the whole update. A failure to
#              fetch the package list itself is fatal (log::die) — an unfetchable list is not the
#              same as an empty one, and must never read as "nothing to do".
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
# @exitcode 0 every package installed
# @exitcode 1 one or more packages failed to install, or the package list could not be fetched
function sdkman_packages::install_sdkman_packages() {
  args::check_no_args "$@"
  local -a pkgs
  local pkgs_tmp
  files::create_temp pkgs_tmp
  # Explicit || log::die rather than relying on errexit: this function is called from an `if`
  # condition, which disables errexit through the whole call tree, so a failed (network) download
  # would otherwise leave an empty list and report a vacuous success.
  packages::get_sdkman > "${pkgs_tmp}" || log::die 'Failed to fetch the SDKMAN package list'
  mapfile -t pkgs < "${pkgs_tmp}"
  local -a failed_pkgs=()
  for pkg in "${pkgs[@]}"; do
    if ! sdkman_packages::install_sdkman_package "${pkg}"; then
      log::warn "Failed to install SDKMAN package: ${pkg}"
      failed_pkgs+=("${pkg}")
    fi
  done
  # Count only: strict IFS=$'\n\t' would make "${failed_pkgs[*]}" join on a newline, and every
  # failure is already named individually above.
  if ((${#failed_pkgs[@]} > 0)); then
    log::warn "Failed to install ${#failed_pkgs[@]} SDKMAN package(s)"
    return 1
  fi
}

# @description Print the names of all installed SDKMAN packages (excluding java).
# Output: stdout — package names, one per line, sorted
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_packages::get_installed_packages() {
  args::check_no_args "$@"
  find "${SDKMAN_CANDIDATES_DIR}" -maxdepth '1' -mindepth '1' -type 'd' ! -name 'java' -printf '%f\n' | sort
}

# @description Print all installed version strings for the given SDKMAN package.
# Output: stdout — version strings, one per line, sorted
# @arg $1 package name
function sdkman_packages::get_installed_packages_versions() {
  args::check_exactly_1_arg "$@"
  local -r package="$1"
  find "${SDKMAN_CANDIDATES_DIR}/${package}" -maxdepth '1' -mindepth '1' -type 'd' -printf '%f\n' | sort
}

# @description Print the currently active version of the given SDKMAN package (via the 'current' symlink target).
# Output: stdout — active version string
# @arg $1 package name
function sdkman_packages::get_current_package_version() {
  args::check_exactly_1_arg "$@"
  local -r package="$1"
  symlinks::get_target "${SDKMAN_CANDIDATES_DIR}/${package}/current"
}

# @description Uninstall all versions of an SDKMAN package except the currently active one.
# @arg $1 package name
function sdkman_packages::prune_sdkman_package() {
  args::check_exactly_1_arg "$@"
  local -r package="$1"
  if ! symlinks::exists "${SDKMAN_CANDIDATES_DIR}/${package}/current"; then
    return 0
  fi
  local current_version
  current_version="$(sdkman_packages::get_current_package_version "${package}")"
  readonly current_version
  local -a versions
  local versions_tmp
  files::create_temp versions_tmp
  sdkman_packages::get_installed_packages_versions "${package}" > "${versions_tmp}"
  mapfile -t versions < "${versions_tmp}"
  for version in "${versions[@]}"; do
    if [[ "${version}" != "${current_version}" ]]; then
      sdkman_packages::uninstall_package_version "${package}" "${version}"
    fi
  done
}

# @description Uninstall all outdated versions of every installed SDKMAN package (excluding java).
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_packages::prune_sdkman_packages() {
  args::check_no_args "$@"
  local -a packages
  local packages_tmp
  files::create_temp packages_tmp
  sdkman_packages::get_installed_packages > "${packages_tmp}"
  mapfile -t packages < "${packages_tmp}"
  for package in "${packages[@]}"; do
    sdkman_packages::prune_sdkman_package "${package}"
  done
}
