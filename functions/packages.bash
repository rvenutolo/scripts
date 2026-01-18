#!/usr/bin/env bash

# $1 = package name
function dpkg_package_installed() {
  dpkg-query --show --showformat='${Package};${Status}\n' "$1" 2> '/dev/null' | contains_regex_ignore_case "^$1;.*ok installed\$"
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
  local packages_to_ignore=()
  local quiet=''
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ignore)
        if [[ $# -lt 2 ]]; then
          die "--ignore requires at least one argument"
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
        die "Unexpected flag '$1'"
        return 1
        ;;
      *)
        # Any remaining non-flag args can be treated as extra inputs or error
        die "Unexpected argument '$1'"
        return 1
        ;;
    esac
  done
  readonly packages_to_ignore
  readonly quiet
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
  if [[ -z "${quiet}" ]]; then
    local disabled_awk_string="\$2 == \"${package_type}\" && \$${package_list_column}== \"y\" && \$8 != \"\" { print \"Disabled package: \" \$3 \" (\" \$8 \")\" }"
    IFS=$'\n'
    for pkg_info in $(download_and_cat "${package_list_url}" | awk -F ',' "${disabled_awk_string}"); do log "$pkg_info"; done
    unset IFS
  fi
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
