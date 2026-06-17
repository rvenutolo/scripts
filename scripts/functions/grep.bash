#!/usr/bin/env bash

# @description Return true if input contains the exact fixed string.
# With 1 arg (stdin): $1 = string to search for.
# With 2 args (file): $1 = file path, $2 = string to search for.
# ex: printf '%s\n' 'foobar' | grep::contains_exactly 'ooba'
# ex: grep::contains_exactly '/path/to/file' 'ooba'
# @arg $1 file path (when 2 args) or string to search for (when 1 arg)
# @arg $2 string to search for (when 2 args)
# @exitcode 0 if true
# @exitcode 1 if false
function grep::contains_exactly() {
  if [[ $# -gt 1 ]]; then
    args::check_exactly_2_args "$@"
    local -r file="$1"
    local -r str="$2"
    files::assert_exists "${file}"
    grep --quiet --fixed-strings -- "${str}" "${file}"
  else
    args::check_exactly_1_arg "$@"
    args::check_for_stdin
    grep --quiet --fixed-strings -- "$1"
  fi
}

# @description Return true if input contains the exact fixed string (case-insensitive).
# With 1 arg (stdin): $1 = string to search for.
# With 2 args (file): $1 = file path, $2 = string to search for.
# @arg $1 file path (when 2 args) or string to search for (when 1 arg)
# @arg $2 string to search for (when 2 args)
# @exitcode 0 if true
# @exitcode 1 if false
function grep::contains_exactly_ignore_case() {
  if [[ $# -gt 1 ]]; then
    args::check_exactly_2_args "$@"
    local -r file="$1"
    local -r str="$2"
    files::assert_exists "${file}"
    grep --quiet --fixed-strings --ignore-case -- "${str}" "${file}"
  else
    args::check_exactly_1_arg "$@"
    args::check_for_stdin
    grep --quiet --fixed-strings --ignore-case -- "$1"
  fi
}

# @description Return true if input contains a line matching the given regex.
# With 1 arg (stdin): $1 = regex pattern.
# With 2 args (file): $1 = file path, $2 = regex pattern.
# @arg $1 file path (when 2 args) or regex pattern (when 1 arg)
# @arg $2 regex pattern (when 2 args)
# @exitcode 0 if true
# @exitcode 1 if false
function grep::contains_regex() {
  if [[ $# -gt 1 ]]; then
    args::check_exactly_2_args "$@"
    local -r file="$1"
    local -r pattern="$2"
    files::assert_exists "${file}"
    grep --quiet -- "${pattern}" "${file}"
  else
    args::check_exactly_1_arg "$@"
    args::check_for_stdin
    grep --quiet -- "$1"
  fi
}

# @description Return true if input contains a line matching the given regex (case-insensitive).
# With 1 arg (stdin): $1 = regex pattern.
# With 2 args (file): $1 = file path, $2 = regex pattern.
# @arg $1 file path (when 2 args) or regex pattern (when 1 arg)
# @arg $2 regex pattern (when 2 args)
# @exitcode 0 if true
# @exitcode 1 if false
function grep::contains_regex_ignore_case() {
  if [[ $# -gt 1 ]]; then
    args::check_exactly_2_args "$@"
    local -r file="$1"
    local -r pattern="$2"
    files::assert_exists "${file}"
    grep --quiet --ignore-case -- "${pattern}" "${file}"
  else
    args::check_exactly_1_arg "$@"
    args::check_for_stdin
    grep --quiet --ignore-case -- "$1"
  fi
}

# @description Return true if input contains a line matching the given Perl-compatible regex.
# With 1 arg (stdin): $1 = Perl-compatible regex pattern.
# With 2 args (file): $1 = file path, $2 = Perl-compatible regex pattern.
# @arg $1 file path (when 2 args) or Perl-compatible regex pattern (when 1 arg)
# @arg $2 Perl-compatible regex pattern (when 2 args)
# @exitcode 0 if true
# @exitcode 1 if false
function grep::contains_perl_regex() {
  if [[ $# -gt 1 ]]; then
    args::check_exactly_2_args "$@"
    local -r file="$1"
    local -r pattern="$2"
    files::assert_exists "${file}"
    grep --quiet --perl-regexp -- "${pattern}" "${file}"
  else
    args::check_exactly_1_arg "$@"
    args::check_for_stdin
    grep --quiet --perl-regexp -- "$1"
  fi
}

# @description Return true if input contains a line matching the given Perl-compatible regex (case-insensitive).
# With 1 arg (stdin): $1 = Perl-compatible regex pattern.
# With 2 args (file): $1 = file path, $2 = Perl-compatible regex pattern.
# @arg $1 file path (when 2 args) or Perl-compatible regex pattern (when 1 arg)
# @arg $2 Perl-compatible regex pattern (when 2 args)
# @exitcode 0 if true
# @exitcode 1 if false
function grep::contains_perl_regex_ignore_case() {
  if [[ $# -gt 1 ]]; then
    args::check_exactly_2_args "$@"
    local -r file="$1"
    local -r pattern="$2"
    files::assert_exists "${file}"
    grep --quiet --ignore-case --perl-regexp -- "${pattern}" "${file}"
  else
    args::check_exactly_1_arg "$@"
    args::check_for_stdin
    grep --quiet --ignore-case --perl-regexp -- "$1"
  fi
}

# @description Return true if input contains the exact fixed string as a whole word.
# With 1 arg (stdin): $1 = word to search for.
# With 2 args (file): $1 = file path, $2 = word to search for.
# @arg $1 file path (when 2 args) or word to search for (when 1 arg)
# @arg $2 word to search for (when 2 args)
# @exitcode 0 if true
# @exitcode 1 if false
function grep::contains_word() {
  if [[ $# -gt 1 ]]; then
    args::check_exactly_2_args "$@"
    local -r file="$1"
    local -r word="$2"
    files::assert_exists "${file}"
    grep --quiet --fixed-strings --word-regexp -- "${word}" "${file}"
  else
    args::check_exactly_1_arg "$@"
    args::check_for_stdin
    grep --quiet --fixed-strings --word-regexp -- "$1"
  fi
}

# @description Return true if input contains the exact fixed string as a whole word (case-insensitive).
# With 1 arg (stdin): $1 = word to search for.
# With 2 args (file): $1 = file path, $2 = word to search for.
# @arg $1 file path (when 2 args) or word to search for (when 1 arg)
# @arg $2 word to search for (when 2 args)
# @exitcode 0 if true
# @exitcode 1 if false
function grep::contains_word_ignore_case() {
  if [[ $# -gt 1 ]]; then
    args::check_exactly_2_args "$@"
    local -r file="$1"
    local -r word="$2"
    files::assert_exists "${file}"
    grep --quiet --fixed-strings --ignore-case --word-regexp -- "${word}" "${file}"
  else
    args::check_exactly_1_arg "$@"
    args::check_for_stdin
    grep --quiet --fixed-strings --ignore-case --word-regexp -- "$1"
  fi
}

# @description Return true if input contains a whole-word regex match.
# With 1 arg (stdin): $1 = regex pattern (matched as whole word).
# With 2 args (file): $1 = file path, $2 = regex pattern (matched as whole word).
# @arg $1 file path (when 2 args) or regex pattern (when 1 arg)
# @arg $2 regex pattern (when 2 args)
# @exitcode 0 if true
# @exitcode 1 if false
function grep::contains_word_regex() {
  if [[ $# -gt 1 ]]; then
    args::check_exactly_2_args "$@"
    local -r file="$1"
    local -r pattern="$2"
    files::assert_exists "${file}"
    grep --quiet --word-regexp -- "${pattern}" "${file}"
  else
    args::check_exactly_1_arg "$@"
    args::check_for_stdin
    grep --quiet --word-regexp -- "$1"
  fi
}

# @description Return true if input contains a whole-word regex match (case-insensitive).
# With 1 arg (stdin): $1 = regex pattern (matched as whole word).
# With 2 args (file): $1 = file path, $2 = regex pattern (matched as whole word).
# @arg $1 file path (when 2 args) or regex pattern (when 1 arg)
# @arg $2 regex pattern (when 2 args)
# @exitcode 0 if true
# @exitcode 1 if false
function grep::contains_word_regex_ignore_case() {
  if [[ $# -gt 1 ]]; then
    args::check_exactly_2_args "$@"
    local -r file="$1"
    local -r pattern="$2"
    files::assert_exists "${file}"
    grep --quiet --ignore-case --word-regexp -- "${pattern}" "${file}"
  else
    args::check_exactly_1_arg "$@"
    args::check_for_stdin
    grep --quiet --ignore-case --word-regexp -- "$1"
  fi
}
