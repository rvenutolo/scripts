#!/usr/bin/env bash

### MISC

# $1 = version or artifact ID
function get_jdk_major_version() {
  check_exactly_1_arg "$@"
  if [[ "$1" =~ ^([0-9]+) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  else
    die "Unexpected version: $1"
  fi
}

### BASIC OPERATIONS

# $1 = jdk artifact ID
function install_jdk() {
  check_exactly_1_arg "$@"
  sdk install java "$1" | clean_sdkman_output
}

# $1 = jdk artifact ID
function uninstall_jdk() {
  check_exactly_1_arg "$@"
  sdk uninstall java "$1" | clean_sdkman_output
}

# $1 = artifact ID
function set_default_jdk_by_id() {
  check_exactly_1_arg "$@"
  sdk default java "$1" | clean_sdkman_output
}

### FORMATTED JDK INFO

# output columns:
# 1 - major version
# 2 - version
# 3 - ID
# 4 - installed ('y'/'n')
#shellcheck disable=SC2120
function get_formatted_all_tem_jdks() {
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

### FILTERING

#shellcheck disable=SC2120
function filter_for_installed() {
  check_no_args "$@"
  check_for_stdin
  awk --field-separator ';' '$4 == "y"'
}

# $1 = major version
function filter_for_major_version() {
  check_exactly_1_arg "$@"
  check_for_stdin
  awk --field-separator ';' --assign "major_version=$1" '$1 == major_version'
}

#shellcheck disable=SC2120
function filter_for_latest_per_major_version() {
  check_no_args "$@"
  check_for_stdin
  awk --field-separator ';' '!seen[$1]++'
}

### GET FIELDS

#shellcheck disable=SC2120
function get_formatted_tem_jdk_major_version_field() {
  check_no_args "$@"
  check_for_stdin
  cut --delimiter ';' --fields='1'
}

#shellcheck disable=SC2120
function get_formatted_tem_jdk_version_field() {
  check_no_args "$@"
  check_for_stdin
  cut --delimiter ';' --fields='2'
}

#shellcheck disable=SC2120
function get_formatted_tem_jdk_artifact_id_field() {
  check_no_args "$@"
  check_for_stdin
  cut --delimiter ';' --fields='3'
}

### AVAILABLE JDKS

# output columns:
# 1 - major version
# 2 - version
# 3 - ID
# 4 - installed ('y'/'n')
#shellcheck disable=SC2120
function get_formatted_latest_available_tem_jdk_major_versions() {
  check_no_args "$@"
  get_formatted_all_tem_jdks \
    | filter_for_latest_per_major_version
}

# $1 = major java version
# output columns:
# 1 - major version
# 2 - version
# 3 - ID
# 4 - installed ('y'/'n')
function get_formatted_latest_available_tem_jdk_for_major_version() {
  check_exactly_1_arg "$@"
  check_available_tem_jdk_major_version "$@"
  get_formatted_all_tem_jdks \
    | filter_for_latest_per_major_version \
    | filter_for_major_version "$1"
}

#shellcheck disable=SC2120
function get_available_tem_jdk_major_versions() {
  check_no_args "$@"
  get_formatted_all_tem_jdks \
    | get_formatted_tem_jdk_major_version_field \
    | sort --numeric-sort \
    | uniq
}

#shellcheck disable=SC2120
function get_latest_available_tem_jdk_major_version() {
  check_no_args "$@"
  get_available_tem_jdk_major_versions \
    | last_line
}

# $1 = major java version
function check_available_tem_jdk_major_version() {
  check_exactly_1_arg "$@"
  if ! get_available_tem_jdk_major_versions | contains_word "$1"; then
    die "Java version $1 is not available"
  fi
}

### INSTALLED JDKS

# output columns:
# 1 - major version
# 2 - version
# 3 - ID
# 4 - installed ('y'/'n')
#shellcheck disable=SC2120
function get_formatted_installed_tem_jdks() {
  check_no_args "$@"
  get_formatted_all_tem_jdks \
    | filter_for_installed
}

# $1 = major version
# output columns:
# 1 - major version
# 2 - version
# 3 - ID
# 4 - installed ('y'/'n')
function get_formatted_installed_tem_jdks_for_major_version() {
  check_exactly_1_arg "$@"
  get_formatted_all_tem_jdks \
    | filter_for_installed \
    | filter_for_major_version "$1"
}

# output columns:
# 1 - major version
# 2 - version
# 3 - ID
# 4 - installed ('y'/'n')
#shellcheck disable=SC2120
function get_formatted_latest_installed_tem_jdk_major_versions() {
  check_no_args "$@"
  get_formatted_all_tem_jdks \
    | filter_for_installed \
    | filter_for_latest_per_major_version
}

# $1 = major java version
# output columns:
# 1 - major version
# 2 - version
# 3 - ID
# 4 - installed ('y'/'n')
function get_formatted_latest_installed_tem_jdk_for_major_version() {
  check_exactly_1_arg "$@"
  check_installed_tem_jdk_major_version "$@"
  get_formatted_all_tem_jdks \
    | filter_for_installed \
    | filter_for_latest_per_major_version \
    | filter_for_major_version "$1"
}

#shellcheck disable=SC2120
function get_installed_tem_jdk_major_versions() {
  check_no_args "$@"
  get_formatted_all_tem_jdks \
    | filter_for_installed \
    | get_formatted_tem_jdk_major_version_field \
    | sort --numeric-sort \
    | uniq
}

#shellcheck disable=SC2120
function get_latest_installed_tem_jdk_major_version() {
  check_no_args "$@"
  get_installed_tem_jdk_major_versions \
    | last_line
}

# $1 = major java version
function check_installed_tem_jdk_major_version() {
  check_exactly_1_arg "$@"
  if ! get_installed_tem_jdk_major_versions | contains_word "$1"; then
    die "Java version $1 is not installed"
  fi
}

# $1 = artifact ID
function is_tem_jdk_artifact_installed() {
  check_exactly_1_arg "$@"
  get_formatted_installed_tem_jdks \
    | get_formatted_tem_jdk_artifact_id_field \
    | contains_word "$1"
}

# $1 = major java version
function get_latest_installed_tem_jdk_artifact_id_for_major_version() {
  check_exactly_1_arg "$@"
  get_formatted_installed_tem_jdks_for_major_version "$1" \
    | first_line \
    | get_formatted_tem_jdk_artifact_id_field
}

### INSTALLING JDKS

# $1 = major version
function install_latest_tem_jdk() {
  check_exactly_1_arg "$@"
  check_available_tem_jdk_major_version "$1"
  local latest_artifact_id
  latest_artifact_id="$(
    get_formatted_latest_available_tem_jdk_for_major_version "$1" \
      | get_formatted_tem_jdk_artifact_id_field
  )" || exit 1
  readonly latest_artifact_id
  install_jdk "${latest_artifact_id}"
}

#shellcheck disable=SC2120
function install_latest_tem_jdks() {
  check_no_args "$@"
  get_available_tem_jdk_major_versions | while read -r major_version; do
    install_latest_tem_jdk "${major_version}"
  done
}

### SETTING DEFAULT JDK

## $1 = major java version
function set_default_sdk_to_latest_installed_for_major_version() {
  check_exactly_1_arg "$@"
  check_installed_tem_jdk_major_version "$1"
  local new_default_artifact_id
  new_default_artifact_id="$(
    get_formatted_latest_installed_tem_jdk_for_major_version "$1" \
      | get_formatted_tem_jdk_artifact_id_field
  )" || exit 1
  readonly new_default_artifact_id
  set_default_jdk_by_id "${new_default_artifact_id}"
}

#shellcheck disable=SC2120
function set_default_jdk_to_latest_installed() {
  check_no_args "$@"
  set_default_sdk_to_latest_installed_for_major_version \
    "$(get_latest_installed_tem_jdk_major_version)"
}

### PRUNE JDKS

# $1 = major java version
function prune_tem_jdks_for_major_version() {
  check_exactly_1_arg "$1"
  local latest_artifact_id
  latest_artifact_id="$(
    get_formatted_latest_available_tem_jdk_for_major_version "$1" \
      | get_formatted_tem_jdk_artifact_id_field
  )" || exit 1
  readonly latest_artifact_id
  get_formatted_installed_tem_jdks_for_major_version "$1" \
    | get_formatted_tem_jdk_artifact_id_field \
    | while read -r artifact_id; do
      if [[ "${artifact_id}" != "${latest_artifact_id}" ]]; then
        uninstall_jdk "${artifact_id}"
      fi
    done
}

#shellcheck disable=SC2120
function prune_tem_jdks() {
  check_no_args "$@"
  get_installed_tem_jdk_major_versions | while read -r major_version; do
    prune_tem_jdks_for_major_version "${major_version}"
  done
}
