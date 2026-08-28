#!/usr/bin/env bash

# @description Print each element of an array on its own line.
# Output: stdout — one element per line
# @arg $@ array elements to print
function arrays::to_lines() { # variadic: any arg count valid
  printf '%s\n' "$@"
}

# @description Return true if the given value equals any of the remaining
# arguments. Comparison is literal: glob metacharacters in the needle match
# themselves. An empty haystack (needle only) always returns false.
# @arg $1 needle value to search for
# @arg $@ haystack candidate values to compare against
# @exitcode 0 needle matches one of the haystack values
# @exitcode 1 needle matches none of them
function arrays::contains() {
  args::check_at_least_1_arg "$@"
  local -r needle="$1"
  shift
  local item
  # Explicit returns rather than a trailing [[ ]] test: a search loop cannot be
  # expressed as a single test. Matches the shape of the call sites it replaces.
  for item in "$@"; do
    if [[ "${item}" == "${needle}" ]]; then
      return 0
    fi
  done
  return 1
}

# @description Set difference: elements in first sorted array missing from second sorted array.
# Both arrays must already be sorted in ascending order; results are undefined for unsorted input.
# Empty arrays are handled correctly: an empty first array yields no output; an empty second array
# yields all elements of the first.
# @arg $1 name of first sorted array (variable name passed as a name-ref)
# @arg $2 name of second sorted array (variable name passed as a name-ref)
# @stdout Elements present in first array but not in second, one per line
function arrays::diff() {
  args::check_exactly_2_args "$@"
  local -r first_name="$1"
  local -r second_name="$2"
  namerefs::assert_available "${first_name}" '__arrays_diff_first_ref'
  namerefs::assert_available "${second_name}" '__arrays_diff_second_ref'
  local -n __arrays_diff_first_ref="${first_name}"
  local -n __arrays_diff_second_ref="${second_name}"
  # Guard against empty arrays: printf '%s\n' with zero args emits one spurious newline, causing
  # comm to see an empty line. Explicitly skip to_lines when the array is empty.
  local first_tmp second_tmp
  files::create_temp first_tmp
  files::create_temp second_tmp
  if [[ "${#__arrays_diff_first_ref[@]}" -gt 0 ]]; then
    arrays::to_lines "${__arrays_diff_first_ref[@]}" > "${first_tmp}"
  fi
  if [[ "${#__arrays_diff_second_ref[@]}" -gt 0 ]]; then
    arrays::to_lines "${__arrays_diff_second_ref[@]}" > "${second_tmp}"
  fi
  comm -23 "${first_tmp}" "${second_tmp}"
}

# @description Populate an array from a space-separated environment-variable override when that
# variable is SET — even to the empty string — and from the given default elements when it is unset.
# The distinction is the point: a set-but-empty override means "no elements", which a test needs in
# order to clear a non-empty default, whereas an unset one means "use the defaults". `${VAR:-}`
# collapses the two cases and cannot express it.
# @arg $1 name of the output array (variable name passed as a name-ref; cleared and repopulated)
# @arg $2 name of the override environment variable
# @arg $@ default elements to use when the override is unset
function arrays::from_env_override() {
  args::check_at_least_2_args "$@"
  local -r out_name="$1"
  local -r var_name="$2"
  namerefs::assert_available "${out_name}" '__arrays_from_env_override_ref'
  local -n __arrays_from_env_override_ref="${out_name}"
  shift 2
  if [[ -v "${var_name}" ]]; then
    # Scoped IFS: the strict global IFS has no space, which would stop read -a
    # from splitting a space-separated override into elements.
    IFS=' ' read -r -a __arrays_from_env_override_ref <<< "${!var_name}"
  else
    __arrays_from_env_override_ref=("$@")
  fi
}
