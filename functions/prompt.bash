#!/usr/bin/env bash

# Prompt the user with a [y/N] question (default: no); return true if the user answers yes.
# $1 = question text
function prompt::ny() {
  args::check_exactly_1_arg "$@"
  REPLY=''
  if misc::auto_answer; then
    REPLY='n'
  fi
  while [[ "${REPLY}" != 'y' && "${REPLY}" != 'n' ]]; do
    printf '\033[0;33m%s [y/N]: \033[0m' "$1"
    read -r
    if [[ "${REPLY}" == [yY] ]]; then
      REPLY='y'
    elif [[ "${REPLY}" == '' || "${REPLY}" == [nN] ]]; then
      REPLY='n'
    fi
  done
  [[ "${REPLY}" == 'y' ]]
}

# Prompt the user with a [Y/n] question (default: yes); return true if the user answers yes.
# $1 = question text
function prompt::yn() {
  args::check_exactly_1_arg "$@"
  REPLY=''
  if misc::auto_answer; then
    REPLY='y'
  fi
  while [[ "${REPLY}" != 'y' && "${REPLY}" != 'n' ]]; do
    printf '\033[0;33m%s [Y/n]: \033[0m' "$1"
    read -r
    if [[ "${REPLY}" == '' || "${REPLY}" == [yY] ]]; then
      REPLY='y'
    elif [[ "${REPLY}" == [nN] ]]; then
      REPLY='n'
    fi
  done
  [[ "${REPLY}" == 'y' ]]
}

# Prompt the user for a free-form value; loops until a non-empty response is given.
# If a default is provided, it is shown in the prompt and accepted on empty input.
# $1 = prompt text
# $2 = default value (optional)
# Output: stdout — the value entered by the user (or the default)
function prompt::for_value() {
  args::check_at_least_1_arg "$@"
  args::check_at_most_2_args "$@"
  if strings::is_not_empty "${2:-}"; then
    REPLY=''
    if misc::auto_answer; then
      REPLY="$2"
    fi
    if strings::is_empty "${REPLY}"; then
      read -rp $'\e[0;33m'"$1 [$2"$']: \e[0m'
      if strings::is_empty "${REPLY}"; then
        REPLY="$2"
      fi
    fi
    printf '%s\n' "${REPLY}"
  else
    REPLY=''
    while strings::is_empty "${REPLY}"; do
      read -rp $'\e[0;33m'"$1"$': \e[0m'
    done
    printf '%s\n' "${REPLY}"
  fi
}
