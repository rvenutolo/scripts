#!/usr/bin/env bash

# expected to pipe to this function, ex: printf '%s\n' 'foobar' | grep::contains_exactly 'ooba'
# $1 = string
function grep::contains_exactly() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  grep --quiet --fixed-strings -- "$1"
}

# expected to pipe to this function, ex: printf '%s\n' 'FOOBAR' | grep::contains_exactly_ignore_case 'ooba'
# $1 = string
function grep::contains_exactly_ignore_case() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  grep --quiet --fixed-strings --ignore-case -- "$1"
}

# expected to pipe to this function, ex: printf '%s\n' 'foobar' | grep::contains_regex '^foo'
# $1 = string
function grep::contains_regex() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  grep --quiet -- "$1"
}

# expected to pipe to this function, ex: printf '%s\n' 'FOOBAR' | grep::contains_regex_ignore_case '^foo'
# $1 = string
function grep::contains_regex_ignore_case() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  grep --quiet --ignore-case -- "$1"
}

# expected to pipe to this function, ex: printf '%s\n' 'foobar' | grep::contains_perl_regex '^foo'
# $1 = string
function grep::contains_perl_regex() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  grep --quiet --perl-regexp -- "$1"
}

# expected to pipe to this function, ex: printf '%s\n' 'FOOBAR' | grep::contains_perl_regex_ignore_case '^foo'
# $1 = string
function grep::contains_perl_regex_ignore_case() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  grep --quiet --ignore-case --perl-regexp -- "$1"
}

# expected to pipe to this function, ex: printf '%s\n' 'foo bar baz' | grep::contains_word 'bar'
# $1 = word
function grep::contains_word() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  grep --quiet --fixed-strings --word-regexp -- "$1"
}

# expected to pipe to this function, ex: printf '%s\n' 'FOO BAR BAZ' | grep::contains_word_ignore_case 'bar'
# $1 = word
function grep::contains_word_ignore_case() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  grep --quiet --fixed-strings --ignore-case --word-regexp -- "$1"
}

# expected to pipe to this function, ex: printf '%s\n' 'foo bar baz' | grep::contains_word_regex '^foo'
# $1 = word
function grep::contains_word_regex() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  grep --quiet --word-regexp -- "$1"
}

# expected to pipe to this function, ex: printf '%s\n' 'FOO BAR BAZ' | grep::contains_word_regex_ignore_case '^foo'
# $1 = word
function grep::contains_word_regex_ignore_case() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  grep --quiet --ignore-case --word-regexp -- "$1"
}

# $1 = file
# $2 = string
function grep::file_contains_exactly() {
  args::check_exactly_2_args "$@"
  files::assert_exists "$1"
  grep --quiet --fixed-strings -- "$2" "$1"
}

# $1 = file
# $2 = string
function grep::file_contains_exactly_ignore_case() {
  args::check_exactly_2_args "$@"
  files::assert_exists "$1"
  grep --quiet --fixed-strings --ignore-case -- "$2" "$1"
}

# $1 = file
# $2 = string
function grep::file_contains_regex() {
  args::check_exactly_2_args "$@"
  files::assert_exists "$1"
  grep --quiet -- "$2" "$1"
}

# $1 = file
# $2 = string
function grep::file_contains_regex_ignore_case() {
  args::check_exactly_2_args "$@"
  files::assert_exists "$1"
  grep --quiet --ignore-case -- "$2" "$1"
}

# $1 = file
# $2 = string
function grep::file_contains_perl_regex() {
  args::check_exactly_2_args "$@"
  files::assert_exists "$1"
  grep --quiet --perl-regexp -- "$2" "$1"
}

# $1 = file
# $2 = string
function grep::file_contains_perl_regex_ignore_case() {
  args::check_exactly_2_args "$@"
  files::assert_exists "$1"
  grep --quiet --ignore-case --perl-regexp -- "$2" "$1"
}

# $1 = file
# $2 = string
function grep::file_contains_word() {
  args::check_exactly_2_args "$@"
  files::assert_exists "$1"
  grep --quiet --fixed-strings --word-regexp -- "$2" "$1"
}

# $1 = file
# $2 = string
function grep::file_contains_word_ignore_case() {
  args::check_exactly_2_args "$@"
  files::assert_exists "$1"
  grep --quiet --fixed-strings --ignore-case --word-regexp -- "$2" "$1"
}

# $1 = file
# $2 = string
function grep::file_contains_word_regex() {
  args::check_exactly_2_args "$@"
  files::assert_exists "$1"
  grep --quiet --word-regexp -- "$2" "$1"
}

# $1 = file
# $2 = string
function grep::file_contains_word_regex_ignore_case() {
  args::check_exactly_2_args "$@"
  files::assert_exists "$1"
  grep --quiet --ignore-case --word-regexp -- "$2" "$1"
}
