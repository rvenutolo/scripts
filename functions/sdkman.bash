#!/usr/bin/env bash

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

function get_available_java_versions() {
  check_no_args "$@"
  sdk list java \
    | grep --fixed-strings '|' \
    | cut --delimiter='|' --fields='6' \
    | trim \
    | grep '\-tem$' \
    | tr '-' '.' \
    | cut --delimiter='.' --fields='1' \
    | sort --numeric-sort \
    | uniq \
    | tr '\n' ' '
}
