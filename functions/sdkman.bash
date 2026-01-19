#!/usr/bin/env bash

function clean_sdkman_output() {
  check_no_args "$@"
  check_for_stdin
  remove_ansi | remove_empty_lines
}

function update_sdkman_metadata() {
  check_no_args "$@"
  sdk update | clean_sdkman_output
}

# output columns:
# 1 - major version
# 2 - version
# 3 - ID
# 4 - installed ('y'/'n')
function get_formatted_tem_jdks() {
  check_no_args "$@"
  sdk list java \
    | awk --field-separator '|' '$4 ~ /^[[:space:]]*tem[[:space:]]*$/ {
      gsub(/^[ \t]+|[ \t]+$/, "", $3)
      gsub(/^[ \t]+|[ \t]+$/, "", $5)
      gsub(/^[ \t]+|[ \t]+$/, "", $6)
      match($3, /^[0-9]+/)
      major = substr($3, RSTART, RLENGTH)
      status = ($5 == "") ? "n" : "y"
      print major ";" $3 ";" $6 ";" status
    }'
}

#shellcheck disable=SC2120
function get_available_tem_jdk_major_versions() {
  check_no_args "$@"
  get_formatted_tem_jdks \
    | awk --field-separator ';' '!seen[$1]++ { print $1 }' \
    | tac
}

# $1 = major java version
function check_tem_jdk_major_version() {
  check_exactly_1_arg "$@"
  if ! get_available_tem_jdk_major_versions | contains_word "$1"; then
    die "Unexpected Java major version: $1"
  fi
}

# $1 = major java version
function get_latest_available_tem_jdk_for_major_version() {
  check_exactly_1_arg "$@"
  check_tem_jdk_major_version "$1"
  get_formatted_tem_jdks \
    | awk --field-separator ';' --assign "major_version=$1" '$1 == major_version { print $3; exit }'
}

# $1 = major java version
function install_latest_tem_jdk() {
  check_exactly_1_arg "$@"
  check_tem_jdk_major_version "$1"
  local latest_artifact
  latest_artifact="$(get_latest_available_tem_jdk_for_major_version "$1")"
  readonly latest_artifact
  sdk install java "${latest_artifact}" | clean_sdkman_output
}

function install_latest_tem_jdks() {
  check_no_args "$@"
  get_available_tem_jdk_major_versions | while read -r major_version; do
    install_latest_tem_jdk "${major_version}"
  done
}

function install_sdkman_packages() {
  check_no_args "$@"
  get_sdkman_packages | while read -r pkg; do
    sdk install "${pkg}" | clean_sdkman_output
  done
}

# $1 = major java version
function get_latest_installed_tem_jdk_for_major_version() {
  check_exactly_1_arg "$@"
  check_tem_jdk_major_version "$1"
  get_formatted_tem_jdks \
    | awk --field-separator ';' --assign "major_version=$1" '$1 == major_version && $4 == "y" { print $3; exit }'
}

# $1 = major java version
function set_default_jdk() {
  check_exactly_1_arg "$@"
  check_tem_jdk_major_version "$1"
  local new_default_version
  new_default_version="$(get_latest_installed_tem_jdk_for_major_version "$1")"
  readonly new_default_version
  sdk default java "${new_default_version}" | clean_sdkman_output
}

#shellcheck disable=SC2120
function get_latest_installed_tem_jdk_major_versions() {
  check_no_args "$@"
  get_formatted_tem_jdks \
    | awk --field-separator ';' '$4 == "y" { print $1; exit }'
}

function set_latest_default_jdk() {
  check_no_args "$@"
  set_default_jdk "$(get_latest_installed_tem_jdk_major_versions)"
}
