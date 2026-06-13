#!/usr/bin/env bash

# @description Sort JSON keys recursively. Reads from stdin or a file argument.
# Output: stdout — JSON with all object keys sorted
# @arg $1 JSON file path (optional; reads stdin if omitted)
function json::sort() {
  if [[ $# -gt 0 ]]; then
    args::check_exactly_1_arg "$@"
    jq --sort-keys '.' "$1"
  else
    args::check_for_stdin
    jq --sort-keys '.'
  fi
}

# @description List leaf key paths (paths to scalar values) in a JSON document,
#              dotted with [N] for array indices, deduped and sorted. Reads from
#              stdin or a file argument. Notes: jq's paths(scalars) keeps a leaf
#              only when its value is truthy, so JSON null and false leaves are
#              omitted (true, numbers including 0, and strings including "" are
#              listed); array indices sort lexicographically ([10] before [2]);
#              dotted output is ambiguous for keys that themselves contain "."
#              or "[".
# Output: stdout — one key path per line, e.g. ".a.b", ".list[0].x"
# @arg $1 JSON file path (optional; reads stdin if omitted)
function json::key_paths() {
  local -r filter='[ paths(scalars) | map(if type == "number" then "[" + tostring + "]" else "." + . end) | join("") ] | unique | .[]'
  if [[ $# -gt 0 ]]; then
    args::check_exactly_1_arg "$@"
    jq --raw-output "${filter}" "$1"
  else
    args::check_for_stdin
    jq --raw-output "${filter}"
  fi
}
