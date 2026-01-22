#!/usr/bin/env bash

#shellcheck disable=SC2120
function clean_sdkman_output() {
  check_no_args "$@"
  check_for_stdin
  remove_ansi | remove_empty_lines
}

#shellcheck disable=SC2120
function update_sdkman_metadata() {
  check_no_args "$@"
  sdk update | clean_sdkman_output
}

# $1 = .sdkmanrc file
function get_sdkmanrc_file_java_artifact_id() {
  check_exactly_1_arg "$@"
  assert_file_exists "$1"
  sed --quiet 's/^java=\(.*\)/\1/p' "$1"
}

# $1 = .sdkmanrc file
# $2 = artifact id
function overwrite_sdkmanrc_file_java_artifact_id() {
  check_exactly_2_args "$@"
  assert_file_exists "$1"
  sed --in-place --expression "s/^java=.*/java=$2/" "$1"
}

# $1 = .sdkmanrc file
function rewrite_sdkmanrc_file_java_version() {
  check_exactly_1_arg "$@"
  assert_file_exists "$1"
  local current_java_artifact_id
  current_java_artifact_id="$(get_sdkmanrc_file_java_artifact_id "$1")" || exit 1
  readonly current_java_artifact_id
  if is_tem_jdk_artifact_installed "${current_java_artifact_id}"; then
    return 0
  fi
  local major_version
  major_version="$(get_jdk_major_version "${current_java_artifact_id}")"
  readonly major_version
  local new_java_artifact_id
  new_java_artifact_id="$(get_latest_installed_tem_jdk_artifact_id_for_major_version "${major_version}")" || exit 1
  readonly new_java_artifact_id
  overwrite_sdkmanrc_file_java_artifact_id "$1" "${new_java_artifact_id}"
}

function rewrite_sdkmanrc_file_java_versions() {
  find "${HOME}" -name '.sdkmanrc' -type 'f' | sort | while read -r file; do
    rewrite_sdkmanrc_file_java_version "${file}"
  done
}
