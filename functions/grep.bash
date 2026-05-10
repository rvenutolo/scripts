#!/usr/bin/env bash

# @description Return true if stdin contains the exact fixed string.
# ex: printf '%s\n' 'foobar' | grep::contains_exactly 'ooba'
# @arg $1 string to search for
# @exitcode 0 if true
# @exitcode 1 if false
function grep::contains_exactly() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  grep --quiet --fixed-strings -- "$1"
}

# @description Return true if stdin contains the exact fixed string (case-insensitive).
# ex: printf '%s\n' 'FOOBAR' | grep::contains_exactly_ignore_case 'ooba'
# @arg $1 string to search for
# @exitcode 0 if true
# @exitcode 1 if false
function grep::contains_exactly_ignore_case() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  grep --quiet --fixed-strings --ignore-case -- "$1"
}

# @description Return true if stdin contains a line matching the given regex.
# ex: printf '%s\n' 'foobar' | grep::contains_regex '^foo'
# @arg $1 regex pattern
# @exitcode 0 if true
# @exitcode 1 if false
function grep::contains_regex() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  grep --quiet -- "$1"
}

# @description Return true if stdin contains a line matching the given regex (case-insensitive).
# ex: printf '%s\n' 'FOOBAR' | grep::contains_regex_ignore_case '^foo'
# @arg $1 regex pattern
# @exitcode 0 if true
# @exitcode 1 if false
function grep::contains_regex_ignore_case() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  grep --quiet --ignore-case -- "$1"
}

# @description Return true if stdin contains a line matching the given Perl-compatible regex.
# ex: printf '%s\n' 'foobar' | grep::contains_perl_regex '^foo'
# @arg $1 Perl-compatible regex pattern
# @exitcode 0 if true
# @exitcode 1 if false
function grep::contains_perl_regex() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  grep --quiet --perl-regexp -- "$1"
}

# @description Return true if stdin contains a line matching the given Perl-compatible regex (case-insensitive).
# ex: printf '%s\n' 'FOOBAR' | grep::contains_perl_regex_ignore_case '^foo'
# @arg $1 Perl-compatible regex pattern
# @exitcode 0 if true
# @exitcode 1 if false
function grep::contains_perl_regex_ignore_case() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  grep --quiet --ignore-case --perl-regexp -- "$1"
}

# @description Return true if stdin contains the exact fixed string as a whole word.
# ex: printf '%s\n' 'foo bar baz' | grep::contains_word 'bar'
# @arg $1 word to search for
# @exitcode 0 if true
# @exitcode 1 if false
function grep::contains_word() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  grep --quiet --fixed-strings --word-regexp -- "$1"
}

# @description Return true if stdin contains the exact fixed string as a whole word (case-insensitive).
# ex: printf '%s\n' 'FOO BAR BAZ' | grep::contains_word_ignore_case 'bar'
# @arg $1 word to search for
# @exitcode 0 if true
# @exitcode 1 if false
function grep::contains_word_ignore_case() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  grep --quiet --fixed-strings --ignore-case --word-regexp -- "$1"
}

# @description Return true if stdin contains a whole-word regex match.
# ex: printf '%s\n' 'foo bar baz' | grep::contains_word_regex '^foo'
# @arg $1 regex pattern (matched as whole word)
# @exitcode 0 if true
# @exitcode 1 if false
function grep::contains_word_regex() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  grep --quiet --word-regexp -- "$1"
}

# @description Return true if stdin contains a whole-word regex match (case-insensitive).
# ex: printf '%s\n' 'FOO BAR BAZ' | grep::contains_word_regex_ignore_case '^foo'
# @arg $1 regex pattern (matched as whole word)
# @exitcode 0 if true
# @exitcode 1 if false
function grep::contains_word_regex_ignore_case() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  grep --quiet --ignore-case --word-regexp -- "$1"
}

# @description Return true if the given file contains the exact fixed string.
# @arg $1 file path
# @arg $2 string to search for
# @exitcode 0 if true
# @exitcode 1 if false
function grep::file_contains_exactly() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r str="$2"
  files::assert_exists "${file}"
  grep --quiet --fixed-strings -- "${str}" "${file}"
}

# @description Return true if the given file contains the exact fixed string (case-insensitive).
# @arg $1 file path
# @arg $2 string to search for
# @exitcode 0 if true
# @exitcode 1 if false
function grep::file_contains_exactly_ignore_case() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r str="$2"
  files::assert_exists "${file}"
  grep --quiet --fixed-strings --ignore-case -- "${str}" "${file}"
}

# @description Return true if the given file contains a line matching the given regex.
# @arg $1 file path
# @arg $2 regex pattern
# @exitcode 0 if true
# @exitcode 1 if false
function grep::file_contains_regex() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r pattern="$2"
  files::assert_exists "${file}"
  grep --quiet -- "${pattern}" "${file}"
}

# @description Return true if the given file contains a line matching the given regex (case-insensitive).
# @arg $1 file path
# @arg $2 regex pattern
# @exitcode 0 if true
# @exitcode 1 if false
function grep::file_contains_regex_ignore_case() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r pattern="$2"
  files::assert_exists "${file}"
  grep --quiet --ignore-case -- "${pattern}" "${file}"
}

# @description Return true if the given file contains a line matching the given Perl-compatible regex.
# @arg $1 file path
# @arg $2 Perl-compatible regex pattern
# @exitcode 0 if true
# @exitcode 1 if false
function grep::file_contains_perl_regex() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r pattern="$2"
  files::assert_exists "${file}"
  grep --quiet --perl-regexp -- "${pattern}" "${file}"
}

# @description Return true if the given file contains a line matching the given Perl-compatible regex (case-insensitive).
# @arg $1 file path
# @arg $2 Perl-compatible regex pattern
# @exitcode 0 if true
# @exitcode 1 if false
function grep::file_contains_perl_regex_ignore_case() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r pattern="$2"
  files::assert_exists "${file}"
  grep --quiet --ignore-case --perl-regexp -- "${pattern}" "${file}"
}

# @description Return true if the given file contains the exact fixed string as a whole word.
# @arg $1 file path
# @arg $2 word to search for
# @exitcode 0 if true
# @exitcode 1 if false
function grep::file_contains_word() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r word="$2"
  files::assert_exists "${file}"
  grep --quiet --fixed-strings --word-regexp -- "${word}" "${file}"
}

# @description Return true if the given file contains the exact fixed string as a whole word (case-insensitive).
# @arg $1 file path
# @arg $2 word to search for
# @exitcode 0 if true
# @exitcode 1 if false
function grep::file_contains_word_ignore_case() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r word="$2"
  files::assert_exists "${file}"
  grep --quiet --fixed-strings --ignore-case --word-regexp -- "${word}" "${file}"
}

# @description Return true if the given file contains a whole-word regex match.
# @arg $1 file path
# @arg $2 regex pattern (matched as whole word)
# @exitcode 0 if true
# @exitcode 1 if false
function grep::file_contains_word_regex() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r pattern="$2"
  files::assert_exists "${file}"
  grep --quiet --word-regexp -- "${pattern}" "${file}"
}

# @description Return true if the given file contains a whole-word regex match (case-insensitive).
# @arg $1 file path
# @arg $2 regex pattern (matched as whole word)
# @exitcode 0 if true
# @exitcode 1 if false
function grep::file_contains_word_regex_ignore_case() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r pattern="$2"
  files::assert_exists "${file}"
  grep --quiet --ignore-case --word-regexp -- "${pattern}" "${file}"
}
