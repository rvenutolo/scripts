#!/usr/bin/env bash

# @description Convert YAML to JSON. Reads from stdin or a file argument.
# Output: stdout — JSON equivalent of the YAML input
# @arg $1 YAML file path (optional; reads stdin if omitted)
function yaml::to_json() {
  if [[ $# -gt 0 ]]; then
    args::check_exactly_1_arg "$@"
    yq --output-format=json '.' "$1"
  else
    args::check_for_stdin
    yq --output-format=json '.'
  fi
}

# @description Convert JSON to YAML. Reads from stdin or a file argument.
# Output: stdout — YAML equivalent of the JSON input
# @arg $1 JSON file path (optional; reads stdin if omitted)
function yaml::from_json() {
  if [[ $# -gt 0 ]]; then
    args::check_exactly_1_arg "$@"
    yq --input-format=json --output-format=yaml '.' "$1"
  else
    args::check_for_stdin
    yq --input-format=json --output-format=yaml '.'
  fi
}
