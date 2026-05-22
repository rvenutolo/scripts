#!/usr/bin/env bash

# @description Die if the given env var name is not a valid shell-style identifier.
# Closes regex-injection in `^${var_name}=` patterns used throughout this file.
# @arg $1 candidate variable name
function env_file::_assert_valid_var_name() {
  args::check_exactly_1_arg "$@"
  local -r var_name="$1"
  if ! [[ ${var_name} =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    log::die "Invalid env var name: ${var_name}"
  fi
}

# @description Die if the given variable does not exist as a key in the env file.
# @arg $1 env file path
# @arg $2 variable name
# @exitcode 0 if true
# @exitcode 1 if false
function env_file::assert_var_exists() {
  args::check_exactly_2_args "$@"
  local -r env_file="$1"
  local -r var_name="$2"
  env_file::_assert_valid_var_name "${var_name}"
  files::assert_exists "${env_file}"
  if ! grep::contains_regex "${env_file}" "^${var_name}="; then
    log::die "${var_name} does not exist in ${env_file}"
  fi
}

# @description Print the value of a variable from an env file.
# Output: stdout — the variable's value (may be empty)
# @arg $1 env file path
# @arg $2 variable name
function env_file::get_var_value() {
  args::check_exactly_2_args "$@"
  local -r env_file="$1"
  local -r var_name="$2"
  env_file::_assert_valid_var_name "${var_name}"
  files::assert_exists "${env_file}"
  env_file::assert_var_exists "${env_file}" "${var_name}"
  grep --regexp="^${var_name}=" -- "${env_file}" | cut --delimiter='=' --fields='2-'
}

# @description Return true if the given variable exists in the env file but has an empty value.
# @arg $1 env file path
# @arg $2 variable name
# @exitcode 0 if true
# @exitcode 1 if false
function env_file::is_var_value_empty() {
  args::check_exactly_2_args "$@"
  local -r env_file="$1"
  local -r var_name="$2"
  env_file::_assert_valid_var_name "${var_name}"
  files::assert_exists "${env_file}"
  env_file::assert_var_exists "${env_file}" "${var_name}"
  strings::is_empty "$(env_file::get_var_value "${env_file}" "${var_name}")"
}

# @description Set the value of a variable in an env file, overwriting any existing value.
# @arg $1 env file path
# @arg $2 variable name
# @arg $3 new value
function env_file::set_var_value() {
  args::check_exactly_3_args "$@"
  local -r env_file="$1"
  local -r var_name="$2"
  local -r new_value="$3"
  env_file::_assert_valid_var_name "${var_name}"
  if [[ ${new_value} == *$'\n'* ]]; then
    log::die 'env file values cannot contain newlines'
  fi
  files::assert_exists "${env_file}"
  env_file::assert_var_exists "${env_file}" "${var_name}"
  local value_escaped
  value_escaped="$(printf '%s\n' "${new_value}" | sed --expression='s/[\/&|]/\\&/g')"
  readonly value_escaped
  sed --in-place "s|^${var_name}=.*$|${var_name}=${value_escaped}|" "${env_file}"
}

# @description Set the value of a variable in an env file only if its current value is empty.
# @arg $1 env file path
# @arg $2 variable name
# @arg $3 new value
function env_file::set_var_value_if_empty() {
  args::check_exactly_3_args "$@"
  local -r env_file="$1"
  local -r var_name="$2"
  local -r new_value="$3"
  env_file::_assert_valid_var_name "${var_name}"
  files::assert_exists "${env_file}"
  env_file::assert_var_exists "${env_file}" "${var_name}"
  if env_file::is_var_value_empty "${env_file}" "${var_name}"; then
    env_file::set_var_value "${env_file}" "${var_name}" "${new_value}"
  fi
}

# @description Interactively prompt the user for a value and write it to a variable in an env file.
# @arg $1 env file path
# @arg $2 variable name
# @arg $3 variable info shown in prompt (optional)
# @arg $4 default value pre-filled in prompt (optional)
function env_file::prompt_var_value() {
  args::check_at_least_2_args "$@"
  args::check_at_most_4_args "$@"
  local -r env_file="$1"
  local -r var_name="$2"
  local -r prompt_info="${3:-}"
  local -r default_value="${4:-}"
  env_file::_assert_valid_var_name "${var_name}"
  files::assert_exists "${env_file}"
  env_file::assert_var_exists "${env_file}" "${var_name}"
  local prompt_text
  if strings::is_not_empty "${prompt_info}"; then
    prompt_text="Enter value for ${var_name} ( ${prompt_info} )"
  else
    prompt_text="Enter value for ${var_name}"
  fi
  readonly prompt_text
  local var_value
  if strings::is_not_empty "${default_value}"; then
    var_value="$(prompt::for_value "${prompt_text}" "${default_value}")"
  else
    var_value="$(prompt::for_value "${prompt_text}")"
  fi
  readonly var_value
  env_file::set_var_value "${env_file}" "${var_name}" "${var_value}"
}

# @description Interactively prompt for a value and write it to a variable in an env file, only if currently empty.
# @arg $1 env file path
# @arg $2 variable name
# @arg $3 variable info shown in prompt (optional)
# @arg $4 default value pre-filled in prompt (optional)
function env_file::prompt_var_value_if_empty() {
  args::check_at_least_2_args "$@"
  args::check_at_most_4_args "$@"
  local -r env_file="$1"
  local -r var_name="$2"
  local -r prompt_info="${3:-}"
  local -r default_value="${4:-}"
  env_file::_assert_valid_var_name "${var_name}"
  files::assert_exists "${env_file}"
  env_file::assert_var_exists "${env_file}" "${var_name}"
  if env_file::is_var_value_empty "${env_file}" "${var_name}"; then
    env_file::prompt_var_value "${env_file}" "${var_name}" "${prompt_info}" "${default_value}"
  fi
}

# @description Prompt for a value with a required default and write it to a variable in an env file.
# @arg $1 env file path
# @arg $2 variable name
# @arg $3 default value
function env_file::prompt_value_with_default() {
  args::check_exactly_3_args "$@"
  local -r env_file="$1"
  local -r var_name="$2"
  local -r default_value="$3"
  env_file::_assert_valid_var_name "${var_name}"
  files::assert_exists "${env_file}"
  env_file::assert_var_exists "${env_file}" "${var_name}"
  env_file::prompt_var_value "${env_file}" "${var_name}" '' "${default_value}"
}

# @description Prompt for a value with a default and write it to a variable in an env file, only if currently empty.
# @arg $1 env file path
# @arg $2 variable name
# @arg $3 default value
function env_file::prompt_value_with_default_if_empty() {
  args::check_exactly_3_args "$@"
  local -r env_file="$1"
  local -r var_name="$2"
  local -r default_value="$3"
  env_file::_assert_valid_var_name "${var_name}"
  files::assert_exists "${env_file}"
  env_file::assert_var_exists "${env_file}" "${var_name}"
  if env_file::is_var_value_empty "${env_file}" "${var_name}"; then
    env_file::prompt_value_with_default "${env_file}" "${var_name}" "${default_value:-}"
  fi
}

# @description Prompt for a password value (pre-filled with a generated password) and write it to a variable in an env file.
# @arg $1 env file path
# @arg $2 variable name
# @arg $3 variable info shown in prompt (optional)
function env_file::prompt_pw_value() {
  args::check_at_least_2_args "$@"
  args::check_at_most_3_args "$@"
  local -r env_file="$1"
  local -r var_name="$2"
  local -r prompt_info="${3:-}"
  env_file::_assert_valid_var_name "${var_name}"
  files::assert_exists "${env_file}"
  env_file::assert_var_exists "${env_file}" "${var_name}"
  env_file::prompt_var_value "${env_file}" "${var_name}" "${prompt_info}" "$(passwords::generate)"
}

# @description Prompt for a password-with-symbols value (pre-filled with a generated password) and write it to a variable.
# @arg $1 env file path
# @arg $2 variable name
# @arg $3 variable info shown in prompt (optional)
function env_file::prompt_pw_with_symbols_value() {
  args::check_at_least_2_args "$@"
  args::check_at_most_3_args "$@"
  local -r env_file="$1"
  local -r var_name="$2"
  local -r prompt_info="${3:-}"
  env_file::_assert_valid_var_name "${var_name}"
  files::assert_exists "${env_file}"
  env_file::assert_var_exists "${env_file}" "${var_name}"
  env_file::prompt_var_value "${env_file}" "${var_name}" "${prompt_info}" "$(passwords::generate_with_symbols)"
}

# @description Prompt for a password value and write it to a variable in an env file, only if currently empty.
# @arg $1 env file path
# @arg $2 variable name
# @arg $3 variable info shown in prompt (optional)
function env_file::prompt_pw_value_if_empty() {
  args::check_at_least_2_args "$@"
  args::check_at_most_3_args "$@"
  local -r env_file="$1"
  local -r var_name="$2"
  local -r prompt_info="${3:-}"
  env_file::_assert_valid_var_name "${var_name}"
  files::assert_exists "${env_file}"
  env_file::assert_var_exists "${env_file}" "${var_name}"
  if env_file::is_var_value_empty "${env_file}" "${var_name}"; then
    env_file::prompt_pw_value "${env_file}" "${var_name}" "${prompt_info}"
  fi
}

# @description Prompt for a password-with-symbols value and write it to a variable in an env file, only if currently empty.
# @arg $1 env file path
# @arg $2 variable name
# @arg $3 variable info shown in prompt (optional)
function env_file::prompt_pw_with_symbols_value_if_empty() {
  args::check_at_least_2_args "$@"
  args::check_at_most_3_args "$@"
  local -r env_file="$1"
  local -r var_name="$2"
  local -r prompt_info="${3:-}"
  env_file::_assert_valid_var_name "${var_name}"
  files::assert_exists "${env_file}"
  env_file::assert_var_exists "${env_file}" "${var_name}"
  if env_file::is_var_value_empty "${env_file}" "${var_name}"; then
    env_file::prompt_pw_with_symbols_value "${env_file}" "${var_name}" "${prompt_info}"
  fi
}
