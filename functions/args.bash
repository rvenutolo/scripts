#!/usr/bin/env bash

function args::check_no_args() {
  if [[ "$#" -ne 0 ]]; then
    log::die 'Expected no arguments'
  fi
}

function args::check_at_most_1_arg() {
  if [[ "$#" -gt 1 ]]; then
    log::die 'Expected at most 1 argument'
  fi
}

function args::check_exactly_1_arg() {
  if [[ "$#" -ne 1 ]]; then
    log::die 'Expected exactly 1 argument'
  fi
}

function args::check_at_least_1_arg() {
  if [[ "$#" -lt 1 ]]; then
    log::die 'Expected at least 1 argument'
  fi
}

function args::check_at_most_2_args() {
  if [[ "$#" -gt 2 ]]; then
    log::die 'Expected at most 2 arguments'
  fi
}

function args::check_exactly_2_args() {
  if [[ "$#" -ne 2 ]]; then
    log::die 'Expected exactly 2 arguments'
  fi
}

function args::check_at_least_2_args() {
  if [[ "$#" -lt 2 ]]; then
    log::die 'Expected at least 2 arguments'
  fi
}

function args::check_at_most_3_args() {
  if [[ "$#" -gt 3 ]]; then
    log::die 'Expected at most 3 arguments'
  fi
}

function args::check_exactly_3_args() {
  if [[ "$#" -ne 3 ]]; then
    log::die 'Expected exactly 3 arguments'
  fi
}

function args::check_at_least_3_args() {
  if [[ "$#" -lt 3 ]]; then
    log::die 'Expected at least 3 arguments'
  fi
}

function args::check_at_most_4_args() {
  if [[ "$#" -gt 4 ]]; then
    log::die 'Expected at most 4 arguments'
  fi
}

function args::check_exactly_4_args() {
  if [[ "$#" -ne 4 ]]; then
    log::die 'Expected exactly 4 arguments'
  fi
}

function args::check_at_least_4_args() {
  if [[ "$#" -lt 4 ]]; then
    log::die 'Expected at least 4 arguments'
  fi
}

#shellcheck disable=SC2120
function args::check_for_stdin() {
  args::check_no_args "$@"
  if [[ -t 0 ]]; then
    log::die 'Expected STDIN'
  fi
}

#shellcheck disable=SC2120
function args::stdin_exists() {
  args::check_no_args "$@"
  ! [[ -t 0 ]]
}
