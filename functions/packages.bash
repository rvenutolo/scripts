#!/usr/bin/env bash

# @description Return true if the given dpkg package is installed and in an 'ok installed' state.
# @arg $1 package name
function packages::dpkg_package_installed() {
  args::check_exactly_1_arg "$@"
  dpkg-query --show --showformat='${Package};${Status}\n' "$1" 2> '/dev/null' \
    | grep::contains_regex_ignore_case "^$1;.*ok installed\$"
}

# @description Print the list of universal packages (appimage/flatpak/nixpkgs) that should be installed on this machine.
# Filters by package type and the column matching the current host, excluding disabled packages.
# --quiet = suppress messages about disabled packages
# --ignore [PACKAGE]... = omit the named packages from output
# Output: stdout — package names, one per line, sorted
# @arg $1 package list type (appimage, flatpak, nixpkgs, or nixpkgs-unstable)
function packages::get_universal() {
  args::check_at_least_1_arg "$@"
  system::require_bash_version 4 0
  local package_type
  case "$1" in
    appimage | flatpak | nixpkgs | nixpkgs-unstable)
      readonly package_type="$1"
      ;;
    *)
      log::die "Unexpected package list type: $1"
      ;;
  esac
  shift
  local packages_to_ignore=()
  local quiet=''
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ignore)
        if [[ $# -lt 2 ]]; then
          log::die '--ignore requires at least one argument'
        fi
        shift
        while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]]; do
          packages_to_ignore+=("$1")
          shift
        done
        ;;
      --quiet)
        quiet=1
        shift
        ;;
      -*)
        log::die "Unexpected flag '$1'"
        ;;
      *)
        # Any remaining non-flag args can be treated as extra inputs or error
        log::die "Unexpected argument '$1'"
        ;;
    esac
  done
  readonly packages_to_ignore
  readonly quiet
  local package_list_url='https://raw.githubusercontent.com/rvenutolo/packages/main/universal.csv'
  readonly package_list_url
  local package_list_column
  if hosts::is_personal && hosts::is_desktop; then
    package_list_column=4
  elif hosts::is_personal && hosts::is_laptop; then
    package_list_column=5
  elif hosts::is_work && hosts::is_laptop; then
    package_list_column=6
  elif hosts::is_server; then
    package_list_column=7
  else
    log::die 'Could not determine which computer this is'
  fi
  readonly package_list_column
  if strings::is_empty "${quiet}"; then
    local -a pkg_infos
    mapfile -t pkg_infos < <(
      downloads::download_and_cat "${package_list_url}" \
        | awk \
          --field-separator ',' \
          --assign "type=${package_type}" \
          --assign "col=${package_list_column}" \
          '$2 == type && $col == "y" && $8 != "" { print "Disabled package: " $3 " (" $8 ")" }'
    )
    for pkg_info in "${pkg_infos[@]}"; do
      log::log "${pkg_info}"
    done
  fi
  comm -23 \
    <(
      downloads::download_and_cat "${package_list_url}" \
        | awk \
          --field-separator ',' \
          --assign "type=${package_type}" \
          --assign "col=${package_list_column}" \
          '$2 == type && $col == "y" && $8 == "" { print $3 }' \
        | sort
    ) \
    <(printf '%s\n' "${packages_to_ignore[@]}" | sort)
}

# @description Print the list of distro packages that should be installed on this machine for the given OS release.
# Fetches the package CSV for the given distro id+codename and filters by current host type.
# --quiet = suppress messages about disabled packages
# --ignore [PACKAGE]... = omit the named packages from output
# Output: stdout — package names, one per line, sorted
# @arg $1 OS id (e.g. "ubuntu")
# @arg $2 OS codename (e.g. "jammy")
function packages::get_distro() {
  args::check_at_least_2_args "$@"
  system::require_bash_version 4 0
  local id="$1"
  readonly id
  shift
  local codename="$1"
  readonly codename
  shift
  local packages_to_ignore=()
  local quiet=''
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ignore)
        if [[ $# -lt 2 ]]; then
          log::die '--ignore requires at least one argument'
        fi
        shift
        while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]]; do
          packages_to_ignore+=("$1")
          shift
        done
        ;;
      --quiet)
        quiet=1
        shift
        ;;
      -*)
        log::die "Unexpected flag '$1'"
        ;;
      *)
        # Any remaining non-flag args can be treated as extra inputs or error
        log::die "Unexpected argument '$1'"
        ;;
    esac
  done
  readonly packages_to_ignore
  readonly quiet
  local package_list_url="https://raw.githubusercontent.com/rvenutolo/packages/main/${id}-${codename}.csv"
  readonly package_list_url
  if ! http::curl --output '/dev/null' --head "${package_list_url}"; then
    log::die "No packages list for ${id} ${codename}"
  fi
  local package_list_column
  if hosts::is_personal && hosts::is_desktop; then
    package_list_column=2
  elif hosts::is_personal && hosts::is_laptop; then
    package_list_column=3
  elif hosts::is_work && hosts::is_laptop; then
    package_list_column=4
  elif hosts::is_server; then
    package_list_column=5
  else
    log::die 'Could not determine which computer this is'
  fi
  readonly package_list_column
  if strings::is_empty "${quiet}"; then
    local -a pkg_infos
    mapfile -t pkg_infos < <(
      downloads::download_and_cat "${package_list_url}" \
        | awk \
          --field-separator ',' \
          --assign "col=${package_list_column}" \
          '$col == "y" && $6 != "" { print "Disabled package: " $1 " (" $6 ")" }'
    )
    for pkg_info in "${pkg_infos[@]}"; do
      log::log "${pkg_info}"
    done
  fi
  comm -23 \
    <(
      downloads::download_and_cat "${package_list_url}" \
        | awk \
          --field-separator ',' \
          --assign "col=${package_list_column}" \
          '$col == "y" && $6 == "" { print $1 }' \
        | sort
    ) \
    <(printf '%s\n' "${packages_to_ignore[@]}" | sort)
}

# @description Print the list of SDKMAN packages that should be installed on this machine.
# Fetches the sdkman.csv package list and filters by current host type.
# --quiet = suppress messages about disabled packages
# --ignore [PACKAGE]... = omit the named packages from output
# Output: stdout — package names, one per line, sorted
# @noargs
function packages::get_sdkman() {
  system::require_bash_version 4 0
  local packages_to_ignore=()
  local quiet=''
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ignore)
        if [[ $# -lt 2 ]]; then
          log::die '--ignore requires at least one argument'
        fi
        shift
        while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]]; do
          packages_to_ignore+=("$1")
          shift
        done
        ;;
      --quiet)
        quiet=1
        shift
        ;;
      -*)
        log::die "Unexpected flag '$1'"
        ;;
      *)
        # Any remaining non-flag args can be treated as extra inputs or error
        log::die "Unexpected argument '$1'"
        ;;
    esac
  done
  readonly packages_to_ignore
  readonly quiet
  local package_list_url='https://raw.githubusercontent.com/rvenutolo/packages/main/sdkman.csv'
  readonly package_list_url
  local package_list_column
  if hosts::is_personal && hosts::is_desktop; then
    package_list_column=3
  elif hosts::is_personal && hosts::is_laptop; then
    package_list_column=4
  elif hosts::is_work && hosts::is_laptop; then
    package_list_column=5
  elif hosts::is_server; then
    package_list_column=6
  else
    log::die 'Could not determine which computer this is'
  fi
  readonly package_list_column
  if strings::is_empty "${quiet}"; then
    local -a pkg_infos
    mapfile -t pkg_infos < <(
      downloads::download_and_cat "${package_list_url}" \
        | awk \
          --field-separator ',' \
          --assign "col=${package_list_column}" \
          '$col == "y" && $7 != "" { print "Disabled package: " $2 " (" $7 ")" }'
    )
    for pkg_info in "${pkg_infos[@]}"; do
      log::log "${pkg_info}"
    done
  fi
  comm -23 \
    <(
      downloads::download_and_cat "${package_list_url}" \
        | awk \
          --field-separator ',' \
          --assign "col=${package_list_column}" \
          '$col == "y" && $7 == "" { print $2 }' \
        | sort
    ) \
    <(printf '%s\n' "${packages_to_ignore[@]}" | sort)
}
