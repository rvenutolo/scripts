#!/usr/bin/env bash

# $1 = package name
function dpkg_package_installed() {
  dpkg-query --show --showformat='${Package};${Status}\n' "$1" 2> '/dev/null' | contains_regex_ignore_case "^$1;.*ok installed\$"
}

# $1 = packages list type (appimage flatpak nixpkgs)
# --quiet = don't output messages about disabled packages
# --ignore [PACKAGE]... ignores those packages
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
    IFS=$'\n'
    for pkg_info in $(
      download_and_cat "${package_list_url}" \
        | awk \
          --field-separator ',' \
          --assign "type=${package_type}" \
          --assign "col=${package_list_column}" \
          '$2 == type && $col == "y" && $8 != "" { print "Disabled package: " $3 " (" $8 ")" }'
    ); do
      log "$pkg_info"
    done
    unset IFS
  fi
  comm -23 \
    <(
      download_and_cat "${package_list_url}" \
        | awk \
          --field-separator ',' \
          --assign "type=${package_type}" \
          --assign "col=${package_list_column}" \
          '$2 == type && $col == "y" && $8 == "" { print $3 }' \
        | sort
    ) \
    <(printf '%s\n' "${packages_to_ignore[@]}" | sort)
}

# $1 = id
# $2 = codename
# --quiet = don't output messages about disabled packages
# --ignore [PACKAGE]... ignores those packages
function get_distro_packages() {
  check_at_least_2_arg "$@"
  local id="$1"
  shift
  local codename="$1"
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
  local package_list_url="https://raw.githubusercontent.com/rvenutolo/packages/main/${id}-${codename}.csv"
  if ! curl_wrapper --output '/dev/null' --head "${package_list_url}"; then
    die "No packages list for ${id} ${codename}"
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
  if [[ -z "${quiet}" ]]; then
    IFS=$'\n'
    for pkg_info in $(
      download_and_cat "${package_list_url}" \
        | awk \
          --field-separator ',' \
          --assign "col=${package_list_column}" \
          '$col == "y" && $6 != "" { print "Disabled package: " $1 " (" $6 ")" }'
    ); do
      log "$pkg_info"
    done
    unset IFS
  fi
  comm -23 \
    <(
      download_and_cat "${package_list_url}" \
        | awk \
          --field-separator ',' \
          --assign "col=${package_list_column}" \
          '&& $col == "y" && $6 == "" { print $1 }' \
        | sort
    ) \
    <(printf '%s\n' "${packages_to_ignore[@]}" | sort)
}

# --quiet = don't output messages about disabled packages
# --ignore [PACKAGE]... ignores those packages
function get_sdkman_packages() {
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
  if [[ -z "${quiet}" ]]; then
    IFS=$'\n'
    for pkg_info in $(
      download_and_cat "${package_list_url}" \
        | awk \
          --field-separator ',' \
          --assign "col=${package_list_column}" \
          '$col == "y" && $7 != "" { print "Disabled package: " $2 " (" $7 ")" }'
    ); do
      log "$pkg_info"
    done
    unset IFS
  fi
  comm -23 \
    <(
      download_and_cat "${package_list_url}" \
        | awk \
          --field-separator ',' \
          --assign "col=${package_list_column}" \
          '&& $col == "y" && $7 == "" { print $2 }' \
        | sort
    ) \
    <(printf '%s\n' "${packages_to_ignore[@]}" | sort)
}
