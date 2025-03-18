#!/usr/bin/env bash

function assert_env_file_var_exists() {
  check_exactly_2_args "$@"
  assert_file_exists "$1"
  if ! file_contains_regex "$1" "^$2="; then
    die "$2 does not exist in $1"
  fi
}

# $1 = env file
# $2 = var
function get_env_file_var_value() {
  check_exactly_2_args "$@"
  assert_file_exists "$1"
  assert_env_file_var_exists "$1" "$2"
  grep "^$2=" "$1" | cut --delimiter='=' --fields='2'
}

# $1 = env file
# $2 = var
function is_env_file_var_value_empty() {
  check_exactly_2_args "$@"
  assert_file_exists "$1"
  assert_env_file_var_exists "$1" "$2"
  [[ -z "$(get_env_file_var_value "$1" "$2")" ]]
}

# $1 = env file
# $2 = var
# $3 = value
function set_env_file_var_value() {
  check_exactly_3_args "$@"
  assert_file_exists "$1"
  assert_env_file_var_exists "$1" "$2"
  local value_escaped
  value_escaped=$(printf '%s\n' "$3" | sed --expression='s/[\/&|]/\\&/g')
  sed --in-place "s|^$2=.*$|$2=${value_escaped}|" "$1"
}

# $1 = env file
# $2 = var
# $3 = value
function set_env_file_var_value_if_empty() {
  check_exactly_3_args "$@"
  assert_file_exists "$1"
  assert_env_file_var_exists "$1" "$2"
  if is_env_file_var_value_empty "$1" "$2"; then
    set_env_file_var_value "$1" "$2" "$3"
  fi
}

# $1 = env file
# $2 = var
# $3 = default_value (optional)
function prompt_and_set_env_file_var_value() {
  check_at_least_2_args "$@"
  check_at_most_3_args "$@"
  assert_file_exists "$1"
  assert_env_file_var_exists "$1" "$2"
  local var_value
  if [[ -n "$3" ]]; then
    var_value="$(prompt_for_value "Enter value for $2" "$3")" || exit 1
  else
    var_value="$(prompt_for_value "Enter value for $2")" || exit 1
  fi
  set_env_file_var_value "$1" "$2" "${var_value}"
}

# $1 = env file
# $2 = var
# $3 = default_value (optional)
function prompt_and_set_env_file_var_value_if_empty() {
  check_at_least_2_args "$@"
  check_at_most_3_args "$@"
  assert_file_exists "$1"
  assert_env_file_var_exists "$1" "$2"
  if is_env_file_var_value_empty "$1" "$2"; then
    prompt_and_set_env_file_var_value "$1" "$2" "$3"
  fi
}
