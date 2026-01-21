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
