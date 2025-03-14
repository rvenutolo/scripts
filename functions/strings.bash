#!/usr/bin/env bash

# $1 = string
function ensure_trailing_slash() {
  check_exactly_1_arg "$@"
  if [[ -n "$1" ]]; then
    case "$1" in
      */) echo "$1" ;;
      *) echo "$1/" ;;
    esac
  else
    echo "$1"
  fi
}

# expected to pipe to this function, ex: echo 'foobar' | contains_exactly 'ooba'
# $1 = string
function contains_exactly() {
  check_exactly_1_arg "$@"
  check_for_stdin
  grep --quiet --fixed-strings "$1"
}

# expected to pipe to this function, ex: echo 'FOOBAR' | contains_exactly_ignore_case 'ooba'
# $1 = string
function contains_exactly_ignore_case() {
  check_exactly_1_arg "$@"
  check_for_stdin
  grep --quiet --fixed-strings --ignore-case "$1"
}

# expected to pipe to this function, ex: echo 'foobar' | contains_regex '^foo'
# $1 = string
function contains_regex() {
  check_exactly_1_arg "$@"
  check_for_stdin
  grep --quiet "$1"
}

# expected to pipe to this function, ex: echo 'FOOBAR' | contains_regex_ignore_case '^foo'
# $1 = string
function contains_regex_ignore_case() {
  check_exactly_1_arg "$@"
  check_for_stdin
  grep --quiet --ignore-case "$1"
}

# expected to pipe to this function, ex: echo 'foobar' | contains_perl_regex '^foo'
# $1 = string
function contains_perl_regex() {
  check_exactly_1_arg "$@"
  check_for_stdin
  grep --quiet --perl-regexp "$1"
}

# expected to pipe to this function, ex: echo 'FOOBAR' | contains_perl_regex_ignore_case '^foo'
# $1 = string
function contains_perl_regex_ignore_case() {
  check_exactly_1_arg "$@"
  check_for_stdin
  grep --quiet --ignore-case --perl-regexp "$1"
}

# expected to pipe to this function, ex: echo 'foo bar baz' | contains_word 'bar'
# $1 = word
function contains_word() {
  check_exactly_1_arg "$@"
  check_for_stdin
  grep --quiet --fixed-strings --word-regex "$1"
}

# expected to pipe to this function, ex: echo 'FOO BAR BAZ' | contains_word_ignore_case 'bar'
# $1 = word
function contains_word_ignore_case() {
  check_exactly_1_arg "$@"
  check_for_stdin
  grep --quiet --fixed-strings --ignore-case --word-regex "$1"
}

# expected to pipe to this function, ex: echo 'foo bar baz' | contains_word_regex '^foo'
# $1 = word
function contains_word_regex() {
  check_exactly_1_arg "$@"
  check_for_stdin
  grep --quiet --word-regex "$1"
}

# expected to pipe to this function, ex: echo 'FOO BAR BAZ' | contains_word_regex_ignore_case '^foo'
# $1 = word
function contains_word_regex_ignore_case() {
  check_exactly_1_arg "$@"
  check_for_stdin
  grep --quiet --ignore-case --word-regex "$1"
}

# $1 = file
# $2 = string
function file_contains_exactly() {
  check_exactly_2_args "$@"
  grep --quiet --fixed-strings "$2" "$1"
}

# $1 = file
# $2 = string
function file_contains_exactly_ignore_case() {
  check_exactly_2_args "$@"
  grep --quiet --fixed-strings --ignore-case "$2" "$1"
}

# $1 = file
# $2 = string
function file_contains_regex() {
  check_exactly_2_args "$@"
  grep --quiet "$2" "$1"
}

# $1 = file
# $2 = string
function file_contains_regex_ignore_case() {
  check_exactly_2_args "$@"
  grep --quiet --ignore-case "$2" "$1"
}

# $1 = file
# $2 = string
function file_contains_perl_regex() {
  check_exactly_1_arg "$@"
  check_for_stdin
  grep --quiet --perl-regexp "$2" "$1"
}

# $1 = file
# $2 = string
function file_contains_perl_regex_ignore_case() {
  check_exactly_1_arg "$@"
  check_for_stdin
  grep --quiet --ignore-case --perl-regexp "$2" "$1"
}

# $1 = file
# $2 = string
function file_contains_word() {
  check_exactly_2_args "$@"
  grep --quiet --fixed-strings --word-regex "$2" "$1"
}

# $1 = file
# $2 = string
function file_contains_word_ignore_case() {
  check_exactly_2_args "$@"
  grep --quiet --fixed-strings --ignore-case --word-regex "$2" "$1"
}

# $1 = file
# $2 = string
function file_contains_word_regex() {
  check_exactly_2_args "$@"
  grep --quiet --word-regex "$2" "$1"
}

# $1 = file
# $2 = string
function file_contains_word_regex_ignore_case() {
  check_exactly_2_args "$@"
  grep --quiet --ignore-case --word-regex "$2" "$1"
}
