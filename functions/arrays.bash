#!/usr/bin/env bash

# @description Print each element of an array on its own line.
# Output: stdout — one element per line
# @arg $@ array elements to print
function arrays::to_lines() {
  printf '%s\n' "$@"
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
