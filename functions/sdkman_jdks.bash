#!/usr/bin/env bash

### MISC

# Extract the major version number from a JDK version string or artifact ID.
# $1 = version string or artifact ID (e.g. "21.0.3-tem" or "21")
# Output: stdout — major version number (e.g. "21")
function sdkman_jdks::get_jdk_major_version() {
  args::check_exactly_1_arg "$@"
  if [[ "$1" =~ ^([0-9]+) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  else
    log::die "Unexpected version: $1"
  fi
}

### BASIC OPERATIONS

# Install a specific JDK artifact via SDKMAN.
# $1 = jdk artifact ID (e.g. "21.0.3-tem")
function sdkman_jdks::install_jdk() {
  args::check_exactly_1_arg "$@"
  sdk install java "$1" | sdkman::clean_output
}

# Uninstall a specific JDK artifact via SDKMAN.
# $1 = jdk artifact ID (e.g. "21.0.3-tem")
function sdkman_jdks::uninstall_jdk() {
  args::check_exactly_1_arg "$@"
  sdk uninstall java "$1" | sdkman::clean_output
}

# Set the given JDK artifact as the SDKMAN default for java.
# $1 = artifact ID (e.g. "21.0.3-tem")
function sdkman_jdks::set_default_jdk_by_id() {
  args::check_exactly_1_arg "$@"
  sdk default java "$1" | sdkman::clean_output
}

### FORMATTED JDK INFO

# Print all available Temurin JDKs in semicolon-delimited format.
# Output: stdout — lines with fields: major;version;artifact-id;installed('y'/'n')
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
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

# Filter formatted JDK lines (from stdin) to only those marked as installed.
# Output: stdout — matching lines in semicolon-delimited format
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
function sdkman_jdks::filter_for_installed() {
  args::check_no_args "$@"
  args::check_for_stdin
  awk --field-separator ';' '$4 == "y"'
}

# Filter formatted JDK lines (from stdin) to only those matching the given major version.
# $1 = major version number
# Output: stdout — matching lines in semicolon-delimited format
function sdkman_jdks::filter_for_major_version() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  awk --field-separator ';' --assign "major_version=$1" '$1 == major_version'
}

# Filter formatted JDK lines (from stdin) to retain only the first (latest) entry per major version.
# Output: stdout — one line per major version in semicolon-delimited format
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
function sdkman_jdks::filter_for_latest_per_major_version() {
  args::check_no_args "$@"
  args::check_for_stdin
  awk --field-separator ';' '!seen[$1]++'
}

### GET FIELDS

# Extract the major version field (column 1) from semicolon-delimited JDK lines on stdin.
# Output: stdout — major version numbers, one per line
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
function sdkman_jdks::get_formatted_tem_jdk_major_version_field() {
  args::check_no_args "$@"
  args::check_for_stdin
  cut --delimiter ';' --fields=1
}

# Extract the full version field (column 2) from semicolon-delimited JDK lines on stdin.
# Output: stdout — version strings, one per line
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
function sdkman_jdks::get_formatted_tem_jdk_version_field() {
  args::check_no_args "$@"
  args::check_for_stdin
  cut --delimiter ';' --fields=2
}

# Extract the artifact ID field (column 3) from semicolon-delimited JDK lines on stdin.
# Output: stdout — artifact IDs, one per line
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
function sdkman_jdks::get_formatted_tem_jdk_artifact_id_field() {
  args::check_no_args "$@"
  args::check_for_stdin
  cut --delimiter ';' --fields=3
}

### AVAILABLE JDKS

# Print the latest available Temurin JDK entry per major version in semicolon-delimited format.
# Output: stdout — one line per major version: major;version;artifact-id;installed('y'/'n')
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
function sdkman_jdks::get_formatted_latest_available_tem_jdk_major_versions() {
  args::check_no_args "$@"
  sdkman_jdks::get_formatted_all_tem_jdks \
    | sdkman_jdks::filter_for_latest_per_major_version
}

# Print the latest available Temurin JDK entry for the given major version in semicolon-delimited format.
# $1 = major java version
# Output: stdout — one line: major;version;artifact-id;installed('y'/'n')
function sdkman_jdks::get_formatted_latest_available_tem_jdk_for_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  sdkman_jdks::check_available_tem_jdk_major_version "${major_version}"
  sdkman_jdks::get_formatted_all_tem_jdks \
    | sdkman_jdks::filter_for_latest_per_major_version \
    | sdkman_jdks::filter_for_major_version "${major_version}"
}

# Print all available Temurin JDK major version numbers, sorted numerically.
# Output: stdout — major version numbers, one per line
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
function sdkman_jdks::get_available_tem_jdk_major_versions() {
  args::check_no_args "$@"
  sdkman_jdks::get_formatted_all_tem_jdks \
    | sdkman_jdks::get_formatted_tem_jdk_major_version_field \
    | sort --numeric-sort \
    | uniq
}

# Print the highest available Temurin JDK major version number.
# Output: stdout — major version number (e.g. "21")
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
function sdkman_jdks::get_latest_available_tem_jdk_major_version() {
  args::check_no_args "$@"
  sdkman_jdks::get_available_tem_jdk_major_versions \
    | text::last_line
}

# Die if the given major version is not available in the SDKMAN Temurin JDK list.
# $1 = major java version
function sdkman_jdks::check_available_tem_jdk_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  if ! sdkman_jdks::get_available_tem_jdk_major_versions | grep::contains_word "${major_version}"; then
    log::die "Java version ${major_version} is not available"
  fi
}

### INSTALLED JDKS

# Print all installed Temurin JDK entries in semicolon-delimited format.
# Output: stdout — lines with fields: major;version;artifact-id;installed('y'/'n')
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
function sdkman_jdks::get_formatted_installed_tem_jdks() {
  args::check_no_args "$@"
  sdkman_jdks::get_formatted_all_tem_jdks \
    | sdkman_jdks::filter_for_installed
}

# Print installed Temurin JDK entries for the given major version in semicolon-delimited format.
# $1 = major version
# Output: stdout — lines with fields: major;version;artifact-id;installed('y'/'n')
function sdkman_jdks::get_formatted_installed_tem_jdks_for_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  sdkman_jdks::get_formatted_all_tem_jdks \
    | sdkman_jdks::filter_for_installed \
    | sdkman_jdks::filter_for_major_version "${major_version}"
}

# Print the latest installed Temurin JDK entry per major version in semicolon-delimited format.
# Output: stdout — one line per major version: major;version;artifact-id;installed('y'/'n')
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
function sdkman_jdks::get_formatted_latest_installed_tem_jdk_major_versions() {
  args::check_no_args "$@"
  sdkman_jdks::get_formatted_all_tem_jdks \
    | sdkman_jdks::filter_for_installed \
    | sdkman_jdks::filter_for_latest_per_major_version
}

# Print the latest installed Temurin JDK entry for the given major version in semicolon-delimited format.
# $1 = major java version
# Output: stdout — one line: major;version;artifact-id;installed('y'/'n')
function sdkman_jdks::get_formatted_latest_installed_tem_jdk_for_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  sdkman_jdks::check_installed_tem_jdk_major_version "${major_version}"
  sdkman_jdks::get_formatted_all_tem_jdks \
    | sdkman_jdks::filter_for_installed \
    | sdkman_jdks::filter_for_latest_per_major_version \
    | sdkman_jdks::filter_for_major_version "${major_version}"
}

# Print all installed Temurin JDK major version numbers, sorted numerically.
# Output: stdout — major version numbers, one per line
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
function sdkman_jdks::get_installed_tem_jdk_major_versions() {
  args::check_no_args "$@"
  sdkman_jdks::get_formatted_all_tem_jdks \
    | sdkman_jdks::filter_for_installed \
    | sdkman_jdks::get_formatted_tem_jdk_major_version_field \
    | sort --numeric-sort \
    | uniq
}

# Print the highest installed Temurin JDK major version number.
# Output: stdout — major version number (e.g. "21")
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
function sdkman_jdks::get_latest_installed_tem_jdk_major_version() {
  args::check_no_args "$@"
  sdkman_jdks::get_installed_tem_jdk_major_versions \
    | text::last_line
}

# Die if the given major version has no installed Temurin JDK.
# $1 = major java version
function sdkman_jdks::check_installed_tem_jdk_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  if ! sdkman_jdks::get_installed_tem_jdk_major_versions | grep::contains_word "${major_version}"; then
    log::die "Java version ${major_version} is not installed"
  fi
}

# Return true if a Temurin JDK with the given artifact ID is currently installed.
# $1 = artifact ID (e.g. "21.0.3-tem")
function sdkman_jdks::is_tem_jdk_artifact_installed() {
  args::check_exactly_1_arg "$@"
  sdkman_jdks::get_formatted_installed_tem_jdks \
    | sdkman_jdks::get_formatted_tem_jdk_artifact_id_field \
    | grep::contains_word "$1"
}

# Print the artifact ID of the latest installed Temurin JDK for the given major version.
# $1 = major java version
# Output: stdout — artifact ID (e.g. "21.0.3-tem")
function sdkman_jdks::get_latest_installed_tem_jdk_artifact_id_for_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  sdkman_jdks::get_formatted_installed_tem_jdks_for_major_version "${major_version}" \
    | text::first_line \
    | sdkman_jdks::get_formatted_tem_jdk_artifact_id_field
}

### INSTALLING JDKS

# Install the latest available Temurin JDK for the given major version.
# $1 = major version
function sdkman_jdks::install_latest_tem_jdk() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  sdkman_jdks::check_available_tem_jdk_major_version "${major_version}"
  local latest_artifact_id
  latest_artifact_id="$(
    sdkman_jdks::get_formatted_latest_available_tem_jdk_for_major_version "${major_version}" \
      | sdkman_jdks::get_formatted_tem_jdk_artifact_id_field
  )"
  readonly latest_artifact_id
  sdkman_jdks::install_jdk "${latest_artifact_id}"
}

# Install the latest available Temurin JDK for every available major version.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
function sdkman_jdks::install_latest_tem_jdks() {
  args::check_no_args "$@"
  while read -r major_version; do
    sdkman_jdks::install_latest_tem_jdk "${major_version}"
  done < <(sdkman_jdks::get_available_tem_jdk_major_versions)
}

### SETTING DEFAULT JDK

# Set the SDKMAN default java to the latest installed Temurin JDK for the given major version.
# $1 = major java version
function sdkman_jdks::set_default_sdk_to_latest_installed_for_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  sdkman_jdks::check_installed_tem_jdk_major_version "${major_version}"
  local new_default_artifact_id
  new_default_artifact_id="$(
    sdkman_jdks::get_formatted_latest_installed_tem_jdk_for_major_version "${major_version}" \
      | sdkman_jdks::get_formatted_tem_jdk_artifact_id_field
  )"
  readonly new_default_artifact_id
  sdkman_jdks::set_default_jdk_by_id "${new_default_artifact_id}"
}

# Set the SDKMAN default java to the latest installed Temurin JDK across all major versions.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
function sdkman_jdks::set_default_jdk_to_latest_installed() {
  args::check_no_args "$@"
  sdkman_jdks::set_default_sdk_to_latest_installed_for_major_version \
    "$(sdkman_jdks::get_latest_installed_tem_jdk_major_version)"
}

### PRUNE JDKS

# Uninstall all installed Temurin JDKs for the given major version except the latest available.
# $1 = major java version
function sdkman_jdks::prune_tem_jdks_for_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  local latest_artifact_id
  latest_artifact_id="$(
    sdkman_jdks::get_formatted_latest_available_tem_jdk_for_major_version "${major_version}" \
      | sdkman_jdks::get_formatted_tem_jdk_artifact_id_field
  )"
  readonly latest_artifact_id
  while read -r artifact_id; do
    if [[ "${artifact_id}" != "${latest_artifact_id}" ]]; then
      sdkman_jdks::uninstall_jdk "${artifact_id}"
    fi
  done < <(
    sdkman_jdks::get_formatted_installed_tem_jdks_for_major_version "${major_version}" \
      | sdkman_jdks::get_formatted_tem_jdk_artifact_id_field
  )
}

# Uninstall all outdated installed Temurin JDKs across every installed major version.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
function sdkman_jdks::prune_tem_jdks() {
  args::check_no_args "$@"
  while read -r major_version; do
    sdkman_jdks::prune_tem_jdks_for_major_version "${major_version}"
  done < <(sdkman_jdks::get_installed_tem_jdk_major_versions)
}
