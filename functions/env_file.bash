#!/usr/bin/env bash

# Die if the given variable does not exist as a key in the env file.
# $1 = env file path
# $2 = variable name
function env_file::assert_var_exists() {
  args::check_exactly_2_args "$@"
  files::assert_exists "$1"
  if ! grep::file_contains_regex "$1" "^$2="; then
    log::die "$2 does not exist in $1"
  fi
}

# Print the value of a variable from an env file.
# $1 = env file path
# $2 = variable name
# Output: stdout — the variable's value (may be empty)
function env_file::get_var_value() {
  args::check_exactly_2_args "$@"
  files::assert_exists "$1"
  env_file::assert_var_exists "$1" "$2"
  grep "^$2=" "$1" | cut --delimiter='=' --fields='2-'
}

# Return true if the given variable exists in the env file but has an empty value.
# $1 = env file path
# $2 = variable name
function env_file::is_var_value_empty() {
  args::check_exactly_2_args "$@"
  files::assert_exists "$1"
  env_file::assert_var_exists "$1" "$2"
  strings::is_empty "$(env_file::get_var_value "$1" "$2")"
}

# Set the value of a variable in an env file, overwriting any existing value.
# $1 = env file path
# $2 = variable name
# $3 = new value
function env_file::set_var_value() {
  args::check_exactly_3_args "$@"
  files::assert_exists "$1"
  env_file::assert_var_exists "$1" "$2"
  local value_escaped
  value_escaped=$(printf '%s\n' "$3" | sed --expression='s/[\/&|]/\\&/g')
  readonly value_escaped
  sed --in-place "s|^$2=.*$|$2=${value_escaped}|" "$1"
}

# Set the value of a variable in an env file only if its current value is empty.
# $1 = env file path
# $2 = variable name
# $3 = new value
function env_file::set_var_value_if_empty() {
  args::check_exactly_3_args "$@"
  files::assert_exists "$1"
  env_file::assert_var_exists "$1" "$2"
  if env_file::is_var_value_empty "$1" "$2"; then
    env_file::set_var_value "$1" "$2" "$3"
  fi
}

# Interactively prompt the user for a value and write it to a variable in an env file.
# $1 = env file path
# $2 = variable name
# $3 = variable info shown in prompt (optional)
# $4 = default value pre-filled in prompt (optional)
function env_file::prompt_var_value() {
  args::check_at_least_2_args "$@"
  args::check_at_most_4_args "$@"
  files::assert_exists "$1"
  env_file::assert_var_exists "$1" "$2"
  local prompt_text
  if strings::is_not_empty "${3:-}"; then
    prompt_text="Enter value for $2 ( $3 )"
  else
    prompt_text="Enter value for $2"
  fi
  readonly prompt_text
  local var_value
  if strings::is_not_empty "${4:-}"; then
    var_value="$(prompt::for_value "${prompt_text}" "$4")"
  else
    var_value="$(prompt::for_value "${prompt_text}")"
  fi
  readonly var_value
  env_file::set_var_value "$1" "$2" "${var_value}"
}

# Interactively prompt for a value and write it to a variable in an env file, only if currently empty.
# $1 = env file path
# $2 = variable name
# $3 = variable info shown in prompt (optional)
# $4 = default value pre-filled in prompt (optional)
function env_file::prompt_var_value_if_empty() {
  args::check_at_least_2_args "$@"
  args::check_at_most_4_args "$@"
  files::assert_exists "$1"
  env_file::assert_var_exists "$1" "$2"
  if env_file::is_var_value_empty "$1" "$2"; then
    env_file::prompt_var_value "$1" "$2" "${3:-}" "${4:-}"
  fi
}

# Prompt for a value with a required default and write it to a variable in an env file.
# $1 = env file path
# $2 = variable name
# $3 = default value
function env_file::prompt_value_with_default() {
  args::check_exactly_3_args "$@"
  files::assert_exists "$1"
  env_file::assert_var_exists "$1" "$2"
  env_file::prompt_var_value "$1" "$2" '' "$3"
}

# Prompt for a value with a default and write it to a variable in an env file, only if currently empty.
# $1 = env file path
# $2 = variable name
# $3 = default value
function env_file::prompt_value_with_default_if_empty() {
  args::check_exactly_3_args "$@"
  files::assert_exists "$1"
  env_file::assert_var_exists "$1" "$2"
  if env_file::is_var_value_empty "$1" "$2"; then
    env_file::prompt_value_with_default "$1" "$2" "${3:-}"
  fi
}

# Prompt for a password value (pre-filled with a generated password) and write it to a variable in an env file.
# $1 = env file path
# $2 = variable name
# $3 = variable info shown in prompt (optional)
function env_file::prompt_pw_value() {
  args::check_at_least_2_args "$@"
  args::check_at_most_3_args "$@"
  files::assert_exists "$1"
  env_file::assert_var_exists "$1" "$2"
  env_file::prompt_var_value "$1" "$2" "${3:-}" "$(passwords::generate)"
}

# Prompt for a password-with-symbols value (pre-filled with a generated password) and write it to a variable.
# $1 = env file path
# $2 = variable name
# $3 = variable info shown in prompt (optional)
function env_file::prompt_pw_with_symbols_value() {
  args::check_at_least_2_args "$@"
  args::check_at_most_3_args "$@"
  files::assert_exists "$1"
  env_file::assert_var_exists "$1" "$2"
  env_file::prompt_var_value "$1" "$2" "${3:-}" "$(passwords::generate_with_symbols)"
}

# Prompt for a password value and write it to a variable in an env file, only if currently empty.
# $1 = env file path
# $2 = variable name
# $3 = variable info shown in prompt (optional)
function env_file::prompt_pw_value_if_empty() {
  args::check_at_least_2_args "$@"
  args::check_at_most_3_args "$@"
  files::assert_exists "$1"
  env_file::assert_var_exists "$1" "$2"
  if env_file::is_var_value_empty "$1" "$2"; then
    env_file::prompt_pw_value "$1" "$2" "${3:-}"
  fi
}

# Prompt for a password-with-symbols value and write it to a variable in an env file, only if currently empty.
# $1 = env file path
# $2 = variable name
# $3 = variable info shown in prompt (optional)
function env_file::prompt_pw_with_symbols_value_if_empty() {
  args::check_at_least_2_args "$@"
  args::check_at_most_3_args "$@"
  files::assert_exists "$1"
  env_file::assert_var_exists "$1" "$2"
  if env_file::is_var_value_empty "$1" "$2"; then
    env_file::prompt_pw_with_symbols_value "$1" "$2" "${3:-}"
  fi
}
