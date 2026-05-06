#!/usr/bin/env bash

### MISC

# $1 = version or artifact ID
function sdkman_jdks::get_jdk_major_version() {
  args::check_exactly_1_arg "$@"
  if [[ "$1" =~ ^([0-9]+) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  else
    log::die "Unexpected version: $1"
  fi
}

### BASIC OPERATIONS

# $1 = jdk artifact ID
function sdkman_jdks::install_jdk() {
  args::check_exactly_1_arg "$@"
  sdk install java "$1" | sdkman::clean_output
}

# $1 = jdk artifact ID
function sdkman_jdks::uninstall_jdk() {
  args::check_exactly_1_arg "$@"
  sdk uninstall java "$1" | sdkman::clean_output
}

# $1 = artifact ID
function sdkman_jdks::set_default_jdk_by_id() {
  args::check_exactly_1_arg "$@"
  sdk default java "$1" | sdkman::clean_output
}

### FORMATTED JDK INFO

# output columns:
# 1 - major version
# 2 - version
# 3 - ID
# 4 - installed ('y'/'n')
#shellcheck disable=SC2120
function sdkman_jdks::get_formatted_all_tem_jdks() {
  args::check_no_args "$@"
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
function sdkman_jdks::filter_for_installed() {
  args::check_no_args "$@"
  args::check_for_stdin
  awk --field-separator ';' '$4 == "y"'
}

# $1 = major version
function sdkman_jdks::filter_for_major_version() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  awk --field-separator ';' --assign "major_version=$1" '$1 == major_version'
}

#shellcheck disable=SC2120
function sdkman_jdks::filter_for_latest_per_major_version() {
  args::check_no_args "$@"
  args::check_for_stdin
  awk --field-separator ';' '!seen[$1]++'
}

### GET FIELDS

#shellcheck disable=SC2120
function sdkman_jdks::get_formatted_tem_jdk_major_version_field() {
  args::check_no_args "$@"
  args::check_for_stdin
  cut --delimiter ';' --fields=1
}

#shellcheck disable=SC2120
function sdkman_jdks::get_formatted_tem_jdk_version_field() {
  args::check_no_args "$@"
  args::check_for_stdin
  cut --delimiter ';' --fields=2
}

#shellcheck disable=SC2120
function sdkman_jdks::get_formatted_tem_jdk_artifact_id_field() {
  args::check_no_args "$@"
  args::check_for_stdin
  cut --delimiter ';' --fields=3
}

### AVAILABLE JDKS

# output columns:
# 1 - major version
# 2 - version
# 3 - ID
# 4 - installed ('y'/'n')
#shellcheck disable=SC2120
function sdkman_jdks::get_formatted_latest_available_tem_jdk_major_versions() {
  args::check_no_args "$@"
  sdkman_jdks::get_formatted_all_tem_jdks \
    | sdkman_jdks::filter_for_latest_per_major_version
}

# $1 = major java version
# output columns:
# 1 - major version
# 2 - version
# 3 - ID
# 4 - installed ('y'/'n')
function sdkman_jdks::get_formatted_latest_available_tem_jdk_for_major_version() {
  args::check_exactly_1_arg "$@"
  sdkman_jdks::check_available_tem_jdk_major_version "$@"
  sdkman_jdks::get_formatted_all_tem_jdks \
    | sdkman_jdks::filter_for_latest_per_major_version \
    | sdkman_jdks::filter_for_major_version "$1"
}

#shellcheck disable=SC2120
function sdkman_jdks::get_available_tem_jdk_major_versions() {
  args::check_no_args "$@"
  sdkman_jdks::get_formatted_all_tem_jdks \
    | sdkman_jdks::get_formatted_tem_jdk_major_version_field \
    | sort --numeric-sort \
    | uniq
}

#shellcheck disable=SC2120
function sdkman_jdks::get_latest_available_tem_jdk_major_version() {
  args::check_no_args "$@"
  sdkman_jdks::get_available_tem_jdk_major_versions \
    | text::last_line
}

# $1 = major java version
function sdkman_jdks::check_available_tem_jdk_major_version() {
  args::check_exactly_1_arg "$@"
  if ! sdkman_jdks::get_available_tem_jdk_major_versions | grep::contains_word "$1"; then
    log::die "Java version $1 is not available"
  fi
}

### INSTALLED JDKS

# output columns:
# 1 - major version
# 2 - version
# 3 - ID
# 4 - installed ('y'/'n')
#shellcheck disable=SC2120
function sdkman_jdks::get_formatted_installed_tem_jdks() {
  args::check_no_args "$@"
  sdkman_jdks::get_formatted_all_tem_jdks \
    | sdkman_jdks::filter_for_installed
}

# $1 = major version
# output columns:
# 1 - major version
# 2 - version
# 3 - ID
# 4 - installed ('y'/'n')
function sdkman_jdks::get_formatted_installed_tem_jdks_for_major_version() {
  args::check_exactly_1_arg "$@"
  sdkman_jdks::get_formatted_all_tem_jdks \
    | sdkman_jdks::filter_for_installed \
    | sdkman_jdks::filter_for_major_version "$1"
}

# output columns:
# 1 - major version
# 2 - version
# 3 - ID
# 4 - installed ('y'/'n')
#shellcheck disable=SC2120
function sdkman_jdks::get_formatted_latest_installed_tem_jdk_major_versions() {
  args::check_no_args "$@"
  sdkman_jdks::get_formatted_all_tem_jdks \
    | sdkman_jdks::filter_for_installed \
    | sdkman_jdks::filter_for_latest_per_major_version
}

# $1 = major java version
# output columns:
# 1 - major version
# 2 - version
# 3 - ID
# 4 - installed ('y'/'n')
function sdkman_jdks::get_formatted_latest_installed_tem_jdk_for_major_version() {
  args::check_exactly_1_arg "$@"
  sdkman_jdks::check_installed_tem_jdk_major_version "$@"
  sdkman_jdks::get_formatted_all_tem_jdks \
    | sdkman_jdks::filter_for_installed \
    | sdkman_jdks::filter_for_latest_per_major_version \
    | sdkman_jdks::filter_for_major_version "$1"
}

#shellcheck disable=SC2120
function sdkman_jdks::get_installed_tem_jdk_major_versions() {
  args::check_no_args "$@"
  sdkman_jdks::get_formatted_all_tem_jdks \
    | sdkman_jdks::filter_for_installed \
    | sdkman_jdks::get_formatted_tem_jdk_major_version_field \
    | sort --numeric-sort \
    | uniq
}

#shellcheck disable=SC2120
function sdkman_jdks::get_latest_installed_tem_jdk_major_version() {
  args::check_no_args "$@"
  sdkman_jdks::get_installed_tem_jdk_major_versions \
    | text::last_line
}

# $1 = major java version
function sdkman_jdks::check_installed_tem_jdk_major_version() {
  args::check_exactly_1_arg "$@"
  if ! sdkman_jdks::get_installed_tem_jdk_major_versions | grep::contains_word "$1"; then
    log::die "Java version $1 is not installed"
  fi
}

# $1 = artifact ID
function sdkman_jdks::is_tem_jdk_artifact_installed() {
  args::check_exactly_1_arg "$@"
  sdkman_jdks::get_formatted_installed_tem_jdks \
    | sdkman_jdks::get_formatted_tem_jdk_artifact_id_field \
    | grep::contains_word "$1"
}

# $1 = major java version
function sdkman_jdks::get_latest_installed_tem_jdk_artifact_id_for_major_version() {
  args::check_exactly_1_arg "$@"
  sdkman_jdks::get_formatted_installed_tem_jdks_for_major_version "$1" \
    | text::first_line \
    | sdkman_jdks::get_formatted_tem_jdk_artifact_id_field
}

### INSTALLING JDKS

# $1 = major version
function sdkman_jdks::install_latest_tem_jdk() {
  args::check_exactly_1_arg "$@"
  sdkman_jdks::check_available_tem_jdk_major_version "$1"
  local latest_artifact_id
  latest_artifact_id="$(
    sdkman_jdks::get_formatted_latest_available_tem_jdk_for_major_version "$1" \
      | sdkman_jdks::get_formatted_tem_jdk_artifact_id_field
  )" || exit 1
  readonly latest_artifact_id
  sdkman_jdks::install_jdk "${latest_artifact_id}"
}

#shellcheck disable=SC2120
function sdkman_jdks::install_latest_tem_jdks() {
  args::check_no_args "$@"
  while read -r major_version; do
    sdkman_jdks::install_latest_tem_jdk "${major_version}"
  done < <(sdkman_jdks::get_available_tem_jdk_major_versions)
}

### SETTING DEFAULT JDK

## $1 = major java version
function sdkman_jdks::set_default_sdk_to_latest_installed_for_major_version() {
  args::check_exactly_1_arg "$@"
  sdkman_jdks::check_installed_tem_jdk_major_version "$1"
  local new_default_artifact_id
  new_default_artifact_id="$(
    sdkman_jdks::get_formatted_latest_installed_tem_jdk_for_major_version "$1" \
      | sdkman_jdks::get_formatted_tem_jdk_artifact_id_field
  )" || exit 1
  readonly new_default_artifact_id
  sdkman_jdks::set_default_jdk_by_id "${new_default_artifact_id}"
}

#shellcheck disable=SC2120
function sdkman_jdks::set_default_jdk_to_latest_installed() {
  args::check_no_args "$@"
  sdkman_jdks::set_default_sdk_to_latest_installed_for_major_version \
    "$(sdkman_jdks::get_latest_installed_tem_jdk_major_version)"
}

### PRUNE JDKS

# $1 = major java version
function sdkman_jdks::prune_tem_jdks_for_major_version() {
  args::check_exactly_1_arg "$@"
  local latest_artifact_id
  latest_artifact_id="$(
    sdkman_jdks::get_formatted_latest_available_tem_jdk_for_major_version "$1" \
      | sdkman_jdks::get_formatted_tem_jdk_artifact_id_field
  )" || exit 1
  readonly latest_artifact_id
  while read -r artifact_id; do
    if [[ "${artifact_id}" != "${latest_artifact_id}" ]]; then
      sdkman_jdks::uninstall_jdk "${artifact_id}"
    fi
  done < <(
    sdkman_jdks::get_formatted_installed_tem_jdks_for_major_version "$1" \
      | sdkman_jdks::get_formatted_tem_jdk_artifact_id_field
  )
}

#shellcheck disable=SC2120
function sdkman_jdks::prune_tem_jdks() {
  args::check_no_args "$@"
  while read -r major_version; do
    sdkman_jdks::prune_tem_jdks_for_major_version "${major_version}"
  done < <(sdkman_jdks::get_installed_tem_jdk_major_versions)
}
