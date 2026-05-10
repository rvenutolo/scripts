#!/usr/bin/env bash

# @description Strip ANSI escape codes and blank lines from stdin (used to clean sdk command output).
# Output: stdout — cleaned text
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman::clean_output() {
  args::check_no_args "$@"
  args::check_for_stdin
  text::remove_ansi | text::remove_empty_lines
}

# @description Refresh SDKMAN metadata (runs 'sdk update' and cleans output).
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman::update_metadata() {
  args::check_no_args "$@"
  sdk update | sdkman::clean_output
}

# @description Print the java artifact ID declared in an .sdkmanrc file.
# Output: stdout — artifact ID string (e.g. "21.0.3-tem")
# @arg $1 .sdkmanrc file path
function sdkman::get_sdkmanrc_file_java_artifact_id() {
  args::check_exactly_1_arg "$@"
  local -r sdkmanrc_file="$1"
  files::assert_exists "${sdkmanrc_file}"
  sed --quiet 's/^java=\(.*\)/\1/p' "${sdkmanrc_file}"
}

# @description Overwrite the java artifact ID in an .sdkmanrc file.
# @arg $1 .sdkmanrc file path
# @arg $2 new artifact ID (e.g. "21.0.3-tem")
function sdkman::overwrite_sdkmanrc_file_java_artifact_id() {
  args::check_exactly_2_args "$@"
  local -r sdkmanrc_file="$1"
  local -r artifact_id="$2"
  files::assert_exists "${sdkmanrc_file}"
  sed --in-place --expression "s/^java=.*/java=${artifact_id}/" "${sdkmanrc_file}"
}

# @description Update the java entry in an .sdkmanrc file to the latest installed Temurin JDK for the same major version.
# No-ops if the currently declared artifact is already installed.
# @arg $1 .sdkmanrc file path
function sdkman::rewrite_sdkmanrc_file_java_version() {
  args::check_exactly_1_arg "$@"
  local -r sdkmanrc_file="$1"
  files::assert_exists "${sdkmanrc_file}"
  local current_java_artifact_id
  current_java_artifact_id="$(sdkman::get_sdkmanrc_file_java_artifact_id "${sdkmanrc_file}")"
  readonly current_java_artifact_id
  if sdkman_jdks::is_tem_jdk_artifact_installed "${current_java_artifact_id}"; then
    return 0
  fi
  local major_version
  major_version="$(sdkman_jdks::get_jdk_major_version "${current_java_artifact_id}")"
  readonly major_version
  local new_java_artifact_id
  new_java_artifact_id="$(
    sdkman_jdks::get_latest_installed_tem_jdk_artifact_id_for_major_version "${major_version}"
  )"
  readonly new_java_artifact_id
  sdkman::overwrite_sdkmanrc_file_java_artifact_id "${sdkmanrc_file}" "${new_java_artifact_id}"
}

# @description Find and print the paths of all .sdkmanrc files under $HOME.
# Output: stdout — sorted list of .sdkmanrc file paths, one per line
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman::list_all_sdkmanrc_files() {
  args::check_no_args "$@"
  find "${HOME}" -type 'd' \( ! -readable -o ! -executable \) -prune -o -type 'f' -name '.sdkmanrc' -print | sort
}

# @description Update the java entry in every .sdkmanrc file found under $HOME.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman::rewrite_sdkmanrc_file_java_versions() {
  args::check_no_args "$@"
  while read -r file; do
    sdkman::rewrite_sdkmanrc_file_java_version "${file}"
  done < <(sdkman::list_all_sdkmanrc_files)
}
