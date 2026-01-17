#!/usr/bin/env bash

# $1 = package name
function dpkg_package_installed() {
  dpkg-query --show --showformat='${Package};${Status}\n' "$1" 2> '/dev/null' | contains_regex_ignore_case "^$1;.*ok installed\$"
}

function get_sdkman_packages() {
  check_no_args "$@"
  local package_list_url='https://raw.githubusercontent.com/rvenutolo/packages/main/sdkman.csv'
  if is_personal && is_desktop; then
    local package_list_column=3
  elif is_personal && is_laptop; then
    local package_list_column=4
  elif is_work && is_laptop; then
    local package_list_column=5
  elif is_server; then
    local package_list_column=6
  else
    die 'Could not determine which computer this is'
  fi
  local disabled_awk_string="\$${package_list_column} == \"y\" && \$7 != \"\" { print \"Disabled package: \" \$2 \" (\" \$7 \")\" }"
  IFS=$'\n'
  for pkg_info in $(download_and_cat "${package_list_url}" | awk -F ',' "${disabled_awk_string}"); do log "$pkg_info"; done
  unset IFS
  local enabled_awk_string="\$${package_list_column} == \"y\" && \$7 == \"\" { print \$2 }"
  download_and_cat "${package_list_url}" | awk -F ',' "${enabled_awk_string}"
}

# $1 = packages list type (appimage flatpak nixpkgs)
function get_universal_packages() {
  check_at_least_1_arg "$@"
  local package_type
  case "$1" in
    appimage | flatpak | nixpkgs)
      readonly package_type="$1"
      ;;
    *)
      die "Unexpected package list type: $1"
      ;;
  esac
  shift
  if [[ "$#" -eq 1 ]]; then
    die "Expected 0 or >1 more args"
  fi
  if [[ "$#" -gt 1 ]]; then
    if [[ "$1" != '--ignore' ]]; then
      die "First argument after package type must be '--ignore'"
    fi
    shift
  fi
  local packages_to_ignore=("$@")
  readonly packages_to_ignore
  local package_list_url='https://raw.githubusercontent.com/rvenutolo/packages/main/universal.csv'
  if is_personal && is_desktop; then
    local package_list_column=4
  elif is_personal && is_laptop; then
    local package_list_column=5
  elif is_work && is_laptop; then
    local package_list_column=6
  elif is_server; then
    local package_list_column=7
  else
    die 'Could not determine which computer this is'
  fi
  local disabled_awk_string="\$2 == \"${package_type}\" && \$${package_list_column}== \"y\" && \$8 != \"\" { print \"Disabled package: \" \$3 \" (\" \$8 \")\" }"
  IFS=$'\n'
  for pkg_info in $(download_and_cat "${package_list_url}" | awk -F ',' "${disabled_awk_string}"); do log "$pkg_info"; done
  unset IFS
  local enabled_awk_string="\$2 == \"${package_type}\" && \$${package_list_column}== \"y\" && \$8 == \"\" { print \$3 }"
  comm -23 <(download_and_cat "${package_list_url}" | awk -F ',' "${enabled_awk_string}" | sort) <(printf '%s\n' "${packages_to_ignore[@]}" | sort)
}

# $1 = id
# $2 = codename
function get_distro_packages() {
  check_exactly_2_args "$@"
  local package_list_url="https://raw.githubusercontent.com/rvenutolo/packages/main/$1-$2.csv"
  if ! curl_wrapper --output '/dev/null' --head "${package_list_url}"; then
    die "No packages list for $1 $2"
  fi
  if is_personal && is_desktop; then
    local package_list_column=2
  elif is_personal && is_laptop; then
    local package_list_column=3
  elif is_work && is_laptop; then
    local package_list_column=4
  elif is_server; then
    local package_list_column=5
  else
    die 'Could not determine which computer this is'
  fi
  local disabled_awk_string="\$${package_list_column} == \"y\" && \$6 != \"\" { print \"Disabled package: \" \$1 \" (\" \$6 \")\" }"
  IFS=$'\n'
  for pkg_info in $(download_and_cat "${package_list_url}" | awk -F ',' "${disabled_awk_string}"); do log "$pkg_info"; done
  unset IFS
  local enabled_awk_string="\$${package_list_column} == \"y\" && \$6 == \"\" { print \$1 }"
  download_and_cat "${package_list_url}" | awk -F ',' "${enabled_awk_string}"
}
