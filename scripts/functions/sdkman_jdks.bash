#!/usr/bin/env bash

### MISC

# @description Extract the major version number from a JDK version string or artifact ID.
# Output: stdout — major version number (e.g. "21")
# @arg $1 version string or artifact ID (e.g. "21.0.3-tem" or "21")
function sdkman_jdks::get_jdk_major_version() {
  args::check_exactly_1_arg "$@"
  local -r version="$1"
  if [[ ${version} =~ ^([0-9]+) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  else
    log::die "Unexpected version: ${version}"
  fi
}

### BASIC OPERATIONS

# @description Install a specific JDK artifact via SDKMAN.
# @arg $1 jdk artifact ID (e.g. "21.0.3-tem")
function sdkman_jdks::install_jdk() {
  args::check_exactly_1_arg "$@"
  sdk install java "$1" | sdkman::clean_output
}

# @description Uninstall a specific JDK artifact via SDKMAN.
# @arg $1 jdk artifact ID (e.g. "21.0.3-tem")
function sdkman_jdks::uninstall_jdk() {
  args::check_exactly_1_arg "$@"
  sdk uninstall java "$1" | sdkman::clean_output
}

# @description Set the given JDK artifact as the SDKMAN default for java.
# @arg $1 artifact ID (e.g. "21.0.3-tem")
function sdkman_jdks::set_default_jdk_by_id() {
  args::check_exactly_1_arg "$@"
  sdk default java "$1" | sdkman::clean_output
}

### FORMATTED JDK INFO

# @description Print all available Temurin JDKs in semicolon-delimited format.
# Output: stdout — lines with fields: major;version;artifact-id;installed('y'/'n')
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_formatted_all_tem_jdks() {
  args::check_no_args "$@"
  sdk list java |
    awk --field-separator '|' '$4 ~ /^[[:space:]]*tem[[:space:]]*$/ {
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

# @description Filter formatted JDK lines (from stdin) to only those marked as installed.
# Output: stdout — matching lines in semicolon-delimited format
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::filter_for_installed() {
  args::check_no_args "$@"
  args::check_for_stdin
  awk --field-separator ';' '$4 == "y"'
}

# @description Filter formatted JDK lines (from stdin) to only those matching the given major version.
# Output: stdout — matching lines in semicolon-delimited format
# @arg $1 major version number
function sdkman_jdks::filter_for_major_version() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  awk --field-separator ';' --assign "major_version=$1" '$1 == major_version'
}

# @description Filter formatted JDK lines (from stdin) to retain only the first (latest) entry per major version.
# Output: stdout — one line per major version in semicolon-delimited format
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::filter_for_latest_per_major_version() {
  args::check_no_args "$@"
  args::check_for_stdin
  awk --field-separator ';' '!seen[$1]++'
}

### GET FIELDS

# @description Extract the major version field (column 1) from semicolon-delimited JDK lines on stdin.
# Output: stdout — major version numbers, one per line
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_formatted_tem_jdk_major_version_field() {
  args::check_no_args "$@"
  args::check_for_stdin
  cut --delimiter ';' --fields=1
}

# @description Extract the full version field (column 2) from semicolon-delimited JDK lines on stdin.
# Output: stdout — version strings, one per line
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_formatted_tem_jdk_version_field() {
  args::check_no_args "$@"
  args::check_for_stdin
  cut --delimiter ';' --fields=2
}

# @description Extract the artifact ID field (column 3) from semicolon-delimited JDK lines on stdin.
# Output: stdout — artifact IDs, one per line
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_formatted_tem_jdk_artifact_id_field() {
  args::check_no_args "$@"
  args::check_for_stdin
  cut --delimiter ';' --fields=3
}

### AVAILABLE JDKS

# @description Print the latest available Temurin JDK entry per major version in semicolon-delimited format.
# Output: stdout — one line per major version: major;version;artifact-id;installed('y'/'n')
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_formatted_latest_available_tem_jdk_major_versions() {
  args::check_no_args "$@"
  sdkman_jdks::get_formatted_all_tem_jdks |
    sdkman_jdks::filter_for_latest_per_major_version
}

# @description Print the latest available Temurin JDK entry for the given major version in semicolon-delimited format.
# Output: stdout — one line: major;version;artifact-id;installed('y'/'n')
# @arg $1 major java version
function sdkman_jdks::get_formatted_latest_available_tem_jdk_for_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  sdkman_jdks::check_available_tem_jdk_major_version "${major_version}"
  sdkman_jdks::get_formatted_all_tem_jdks |
    sdkman_jdks::filter_for_latest_per_major_version |
    sdkman_jdks::filter_for_major_version "${major_version}"
}

# @description Print all available Temurin JDK major version numbers, sorted numerically.
# Output: stdout — major version numbers, one per line
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_available_tem_jdk_major_versions() {
  args::check_no_args "$@"
  sdkman_jdks::get_formatted_all_tem_jdks |
    sdkman_jdks::get_formatted_tem_jdk_major_version_field |
    sort --numeric-sort |
    uniq
}

# @description Print the highest available Temurin JDK major version number.
# Output: stdout — major version number (e.g. "21")
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_latest_available_tem_jdk_major_version() {
  args::check_no_args "$@"
  sdkman_jdks::get_available_tem_jdk_major_versions |
    text::last_line
}

# @description Die if the given major version is not available in the SDKMAN Temurin JDK list.
# @arg $1 major java version
function sdkman_jdks::check_available_tem_jdk_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  if ! sdkman_jdks::get_available_tem_jdk_major_versions | grep::contains_word "${major_version}"; then
    log::die "Java version ${major_version} is not available"
  fi
}

### INSTALLED JDKS

# @description Print all installed Temurin JDK entries in semicolon-delimited format.
# Output: stdout — lines with fields: major;version;artifact-id;installed('y'/'n')
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_formatted_installed_tem_jdks() {
  args::check_no_args "$@"
  sdkman_jdks::get_formatted_all_tem_jdks |
    sdkman_jdks::filter_for_installed
}

# @description Print installed Temurin JDK entries for the given major version in semicolon-delimited format.
# Output: stdout — lines with fields: major;version;artifact-id;installed('y'/'n')
# @arg $1 major version
function sdkman_jdks::get_formatted_installed_tem_jdks_for_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  sdkman_jdks::get_formatted_all_tem_jdks |
    sdkman_jdks::filter_for_installed |
    sdkman_jdks::filter_for_major_version "${major_version}"
}

# @description Print the latest installed Temurin JDK entry per major version in semicolon-delimited format.
# Output: stdout — one line per major version: major;version;artifact-id;installed('y'/'n')
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_formatted_latest_installed_tem_jdk_major_versions() {
  args::check_no_args "$@"
  sdkman_jdks::get_formatted_all_tem_jdks |
    sdkman_jdks::filter_for_installed |
    sdkman_jdks::filter_for_latest_per_major_version
}

# @description Print the latest installed Temurin JDK entry for the given major version in semicolon-delimited format.
# Output: stdout — one line: major;version;artifact-id;installed('y'/'n')
# @arg $1 major java version
function sdkman_jdks::get_formatted_latest_installed_tem_jdk_for_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  sdkman_jdks::check_installed_tem_jdk_major_version "${major_version}"
  sdkman_jdks::get_formatted_all_tem_jdks |
    sdkman_jdks::filter_for_installed |
    sdkman_jdks::filter_for_latest_per_major_version |
    sdkman_jdks::filter_for_major_version "${major_version}"
}

# @description Print all installed Temurin JDK major version numbers, sorted numerically.
# Output: stdout — major version numbers, one per line
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_installed_tem_jdk_major_versions() {
  args::check_no_args "$@"
  sdkman_jdks::get_formatted_all_tem_jdks |
    sdkman_jdks::filter_for_installed |
    sdkman_jdks::get_formatted_tem_jdk_major_version_field |
    sort --numeric-sort |
    uniq
}

# @description Print the highest installed Temurin JDK major version number.
# Output: stdout — major version number (e.g. "21")
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_latest_installed_tem_jdk_major_version() {
  args::check_no_args "$@"
  sdkman_jdks::get_installed_tem_jdk_major_versions |
    text::last_line
}

# @description Die if the given major version has no installed Temurin JDK.
# @arg $1 major java version
function sdkman_jdks::check_installed_tem_jdk_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  if ! sdkman_jdks::get_installed_tem_jdk_major_versions | grep::contains_word "${major_version}"; then
    log::die "Java version ${major_version} is not installed"
  fi
}

# @description Return true if a Temurin JDK with the given artifact ID is currently installed.
# @arg $1 artifact ID (e.g. "21.0.3-tem")
# @exitcode 0 if true
# @exitcode 1 if false
function sdkman_jdks::is_tem_jdk_artifact_installed() {
  args::check_exactly_1_arg "$@"
  sdkman_jdks::get_formatted_installed_tem_jdks |
    sdkman_jdks::get_formatted_tem_jdk_artifact_id_field |
    grep::contains_word "$1"
}

# @description Print the artifact ID of the latest installed Temurin JDK for the given major version.
# Output: stdout — artifact ID (e.g. "21.0.3-tem")
# @arg $1 major java version
function sdkman_jdks::get_latest_installed_tem_jdk_artifact_id_for_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  sdkman_jdks::get_formatted_installed_tem_jdks_for_major_version "${major_version}" |
    text::first_line |
    sdkman_jdks::get_formatted_tem_jdk_artifact_id_field
}

### INSTALLING JDKS

# @description Install the latest available Temurin JDK for the given major version.
# @arg $1 major version
function sdkman_jdks::install_latest_tem_jdk() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  sdkman_jdks::check_available_tem_jdk_major_version "${major_version}"
  local latest_artifact_id
  latest_artifact_id="$(
    sdkman_jdks::get_formatted_latest_available_tem_jdk_for_major_version "${major_version}" |
      sdkman_jdks::get_formatted_tem_jdk_artifact_id_field
  )"
  readonly latest_artifact_id
  sdkman_jdks::install_jdk "${latest_artifact_id}"
}

# @description Install the latest available Temurin JDK for every available major version.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::install_latest_tem_jdks() {
  args::check_no_args "$@"
  local -a major_versions
  local major_versions_tmp
  files::create_temp major_versions_tmp
  sdkman_jdks::get_available_tem_jdk_major_versions >"${major_versions_tmp}"
  mapfile -t major_versions <"${major_versions_tmp}"
  for major_version in "${major_versions[@]}"; do
    sdkman_jdks::install_latest_tem_jdk "${major_version}"
  done
}

### SETTING DEFAULT JDK

# @description Set the SDKMAN default java to the latest installed Temurin JDK for the given major version.
# @arg $1 major java version
function sdkman_jdks::set_default_sdk_to_latest_installed_for_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  sdkman_jdks::check_installed_tem_jdk_major_version "${major_version}"
  local new_default_artifact_id
  new_default_artifact_id="$(
    sdkman_jdks::get_formatted_latest_installed_tem_jdk_for_major_version "${major_version}" |
      sdkman_jdks::get_formatted_tem_jdk_artifact_id_field
  )"
  readonly new_default_artifact_id
  sdkman_jdks::set_default_jdk_by_id "${new_default_artifact_id}"
}

# @description Return true if a default java is currently set (the SDKMAN java/current symlink exists).
# @exitcode 0 if a default java is set
# @exitcode 1 if no default java is set
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::has_default_jdk() {
  args::check_no_args "$@"
  symlinks::exists "${SDKMAN_CANDIDATES_DIR}/java/current"
}

# @description Print the major version of the current default java. Dies if no default is set.
# Output: stdout — major version number (e.g. "17")
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_current_default_jdk_major_version() {
  args::check_no_args "$@"
  local target
  target="$(symlinks::get_target "${SDKMAN_CANDIDATES_DIR}/java/current")"
  readonly target
  local -r artifact="${target##*/}"
  sdkman_jdks::get_jdk_major_version "${artifact}"
}

# @description Set the SDKMAN default java to the latest installed Temurin JDK of the current default's major version.
# Falls back to the highest installed major version when no default is currently set.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::set_default_jdk_to_latest_patch_of_current_major() {
  args::check_no_args "$@"
  local major_version
  if sdkman_jdks::has_default_jdk; then
    major_version="$(sdkman_jdks::get_current_default_jdk_major_version)"
  else
    major_version="$(sdkman_jdks::get_latest_installed_tem_jdk_major_version)"
  fi
  readonly major_version
  sdkman_jdks::set_default_sdk_to_latest_installed_for_major_version "${major_version}"
}

### PRUNE JDKS

# @description Uninstall all installed Temurin JDKs for the given major version except the latest available.
# @arg $1 major java version
function sdkman_jdks::prune_tem_jdks_for_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  local latest_artifact_id
  latest_artifact_id="$(
    sdkman_jdks::get_formatted_latest_available_tem_jdk_for_major_version "${major_version}" |
      sdkman_jdks::get_formatted_tem_jdk_artifact_id_field
  )"
  readonly latest_artifact_id
  local -a artifact_ids
  local artifact_ids_tmp
  files::create_temp artifact_ids_tmp
  sdkman_jdks::get_formatted_installed_tem_jdks_for_major_version "${major_version}" |
    sdkman_jdks::get_formatted_tem_jdk_artifact_id_field \
      >"${artifact_ids_tmp}"
  mapfile -t artifact_ids <"${artifact_ids_tmp}"
  for artifact_id in "${artifact_ids[@]}"; do
    if [[ ${artifact_id} != "${latest_artifact_id}" ]]; then
      sdkman_jdks::uninstall_jdk "${artifact_id}"
    fi
  done
}

# @description Uninstall all outdated installed Temurin JDKs across every installed major version.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::prune_tem_jdks() {
  args::check_no_args "$@"
  local -a major_versions
  local major_versions_tmp
  files::create_temp major_versions_tmp
  sdkman_jdks::get_installed_tem_jdk_major_versions >"${major_versions_tmp}"
  mapfile -t major_versions <"${major_versions_tmp}"
  for major_version in "${major_versions[@]}"; do
    sdkman_jdks::prune_tem_jdks_for_major_version "${major_version}"
  done
}
