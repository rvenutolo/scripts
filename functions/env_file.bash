#!/usr/bin/env bash

# $1 = env file
# $2 = var
function env_file_var_exists() {
  check_exactly_2_args "$@"
  assert_file_exists "$1"
  file_contains_regex "^$2=" "$1"
}

# $1 = env file
# $2 = var
function get_env_file_var_value() {
  check_exactly_2_args "$@"
  assert_file_exists "$1"
  if ! env_file_var_exists "$1" "$2"; then
    die "$2 does not exist in $1"
  fi
  grep "^$2=" "$1" | cut --delimiter='=' --fields='2'
}

# $1 = env file
# $2 = var
function is_env_file_var_value_defined() {
  check_exactly_2_args "$@"
  assert_file_exists "$1"
  [[ -n "$(get_env_file_var "$1" "$2")" ]]
}

# $1 = env file
# $2 = var
function get_env_file_defined_var_value() {
  check_exactly_2_args "$@"
  assert_file_exists "$1"
  if ! is_env_file_var_value_defined "$1" "$2"; then
    die "$2 is not defined in $1"
  fi
  get_env_file_var_value "$1" "$2"
}

# $1 = env file
# $2 = var
# $3 = value
function set_env_file_var_value() {
  check_exactly_3_args "$@"
  assert_file_exists "$1"
  if ! env_file_var_exists "$1" "$2"; then
    die "$2 does not exist in $1"
  fi
  sed --in-place "s|^$2=.*$|$2=$3|" "$1"
}

# $1 = env file
# $2 = var
# $3 = value
function set_env_file_var_value_if_not_defined() {
  check_exactly_3_args "$@"
  assert_file_exists "$1"
  if ! is_env_file_var_value_defined "$1" "$2"; then
    set_env_file_var_value "$1" "$2" "$3"
  fi
}

# $1 = env file
# $2 = var
# $3 = info (optional)
function prompt_and_set_env_file_var_value() {
  check_at_least_2_args "$@"
  check_at_most_3_args "$@"
  assert_file_exists "$1"
  local var_value
  if [[ -n "$3" ]]; then
    var_value="$(prompt_for_value "Enter value for $2 [ $3 ]")" || exit 1
  else
    var_value="$(prompt_for_value "Enter value for $2")" || exit 1
  fi
  set_env_file_var_value "$1" "$2" "${var_value}"
}

# $1 = env file
# $2 = var
# $3 = info (optional)
function prompt_and_define_env_file_var_value() {
  check_at_least_2_args "$@"
  check_at_most_3_args "$@"
  assert_file_exists "$1"
  if ! is_env_file_var_value_defined "$1" "$2"; then
    prompt_and_set_env_file_var_value "$1" "$2" "${3:-}"
  fi
}

# $1 = env file
# $2 = var
# $3 = default_value
function prompt_and_set_env_file_var_value_with_default() {
  check_exactly_3_args "$@"
  assert_file_exists "$1"
  local var_value
  var_value="$(prompt_for_value "Enter value for $2" "$3")" || exit 1
  set_env_file_var_value "$1" "$2" "${var_value}"
}

# $1 = env file
# $2 = var
# $3 = default_value
function prompt_and_define_env_file_var_value_with_default() {
  check_exactly_3_args "$@"
  assert_file_exists "$1"
  if ! is_env_file_var_value_defined "$1" "$2"; then
    prompt_and_set_env_file_var_value_with_default "$1" "$2" "$3"
  fi
}
