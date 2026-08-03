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
    if [[ ${item} == "${needle}" ]]; then
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
  local -n first_array="$1"
  local -n second_array="$2"
  # Guard against empty arrays: printf '%s\n' with zero args emits one spurious newline, causing
  # comm to see an empty line. Explicitly skip to_lines when the array is empty.
  local first_tmp second_tmp
  files::create_temp first_tmp
  files::create_temp second_tmp
  [[ ${#first_array[@]} -gt 0 ]] && arrays::to_lines "${first_array[@]}" > "${first_tmp}" || true
  [[ ${#second_array[@]} -gt 0 ]] && arrays::to_lines "${second_array[@]}" > "${second_tmp}" || true
  comm -23 "${first_tmp}" "${second_tmp}"
}
