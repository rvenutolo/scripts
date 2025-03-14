#!/usr/bin/env bash

# $1 = question
function prompt_ny() {
  check_exactly_1_arg "$@"
  REPLY=''
  if auto_answer; then
    REPLY='n'
  fi
  while [[ "${REPLY}" != 'y' && "${REPLY}" != 'n' ]]; do
    echo -e -n "\033[0;33m$1 [y/N]: \033[0m"
    read -r
    if [[ "${REPLY}" == [yY] ]]; then
      REPLY='y'
    elif [[ "${REPLY}" == '' || "${REPLY}" == [nN] ]]; then
      REPLY='n'
    fi
  done
  [[ "${REPLY}" == 'y' ]]
}

# $1 = question
function prompt_yn() {
  check_exactly_1_arg "$@"
  REPLY=''
  if auto_answer; then
    REPLY='y'
  fi
  while [[ "${REPLY}" != 'y' && "${REPLY}" != 'n' ]]; do
    echo -e -n "\033[0;33m$1 [Y/n]: \033[0m"
    read -r
    if [[ "${REPLY}" == '' || "${REPLY}" == [yY] ]]; then
      REPLY='y'
    elif [[ "${REPLY}" == [nN] ]]; then
      REPLY='n'
    fi
  done
  [[ "${REPLY}" == 'y' ]]
}

# $1 = question
# $2 = default value (optional)
function prompt_for_value() {
  check_at_least_1_arg "$@"
  check_at_most_2_args "$@"
  if [[ -n "${2:-}" ]]; then
    REPLY=''
    if auto_answer; then
      REPLY="$2"
    fi
    if [[ "${REPLY}" == '' ]]; then
      read -rp $'\e[0;33m'"$1 [$2"$']: \e[0m'
      if [[ "${REPLY}" == '' ]]; then
        REPLY="$2"
      fi
    fi
    echo "${REPLY}"
  else
    REPLY=''
    while [[ -z "${REPLY}" ]]; do
      read -rp $'\e[0;33m'"$1"$': \e[0m'
    done
    echo "${REPLY}"
  fi
}
