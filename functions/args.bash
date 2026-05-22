#!/usr/bin/env bash

# @description Die if called with any arguments.
# @arg $@ caller's arguments (count-checked; 0 expected)
function args::check_no_args() {
  if [[ $# -ne 0 ]]; then
    log::die 'Expected no arguments'
  fi
}

# @description Die if called with more than 1 argument.
# @arg $@ caller's arguments (count-checked; ≤1 expected)
function args::check_at_most_1_arg() {
  if [[ $# -gt 1 ]]; then
    log::die 'Expected at most 1 argument'
  fi
}

# @description Die if not called with exactly 1 argument.
# @arg $@ caller's arguments (count-checked; exactly 1 expected)
function args::check_exactly_1_arg() {
  if [[ $# -ne 1 ]]; then
    log::die 'Expected exactly 1 argument'
  fi
}

# @description Die if called with fewer than 1 argument.
# @arg $@ caller's arguments (count-checked; ≥1 expected)
function args::check_at_least_1_arg() {
  if [[ $# -lt 1 ]]; then
    log::die 'Expected at least 1 argument'
  fi
}

# @description Die if called with more than 2 arguments.
# @arg $@ caller's arguments (count-checked; ≤2 expected)
function args::check_at_most_2_args() {
  if [[ $# -gt 2 ]]; then
    log::die 'Expected at most 2 arguments'
  fi
}

# @description Die if not called with exactly 2 arguments.
# @arg $@ caller's arguments (count-checked; exactly 2 expected)
function args::check_exactly_2_args() {
  if [[ $# -ne 2 ]]; then
    log::die 'Expected exactly 2 arguments'
  fi
}

# @description Die if called with fewer than 2 arguments.
# @arg $@ caller's arguments (count-checked; ≥2 expected)
function args::check_at_least_2_args() {
  if [[ $# -lt 2 ]]; then
    log::die 'Expected at least 2 arguments'
  fi
}

# @description Die if called with more than 3 arguments.
# @arg $@ caller's arguments (count-checked; ≤3 expected)
function args::check_at_most_3_args() {
  if [[ $# -gt 3 ]]; then
    log::die 'Expected at most 3 arguments'
  fi
}

# @description Die if not called with exactly 3 arguments.
# @arg $@ caller's arguments (count-checked; exactly 3 expected)
function args::check_exactly_3_args() {
  if [[ $# -ne 3 ]]; then
    log::die 'Expected exactly 3 arguments'
  fi
}

# @description Die if called with fewer than 3 arguments.
# @arg $@ caller's arguments (count-checked; ≥3 expected)
function args::check_at_least_3_args() {
  if [[ $# -lt 3 ]]; then
    log::die 'Expected at least 3 arguments'
  fi
}

# @description Die if called with more than 4 arguments.
# @arg $@ caller's arguments (count-checked; ≤4 expected)
function args::check_at_most_4_args() {
  if [[ $# -gt 4 ]]; then
    log::die 'Expected at most 4 arguments'
  fi
}

# @description Die if not called with exactly 4 arguments.
# @arg $@ caller's arguments (count-checked; exactly 4 expected)
function args::check_exactly_4_args() {
  if [[ $# -ne 4 ]]; then
    log::die 'Expected exactly 4 arguments'
  fi
}

# @description Die if called with fewer than 4 arguments.
# @arg $@ caller's arguments (count-checked; ≥4 expected)
function args::check_at_least_4_args() {
  if [[ $# -lt 4 ]]; then
    log::die 'Expected at least 4 arguments'
  fi
}

# @description Return true if called with exactly the given number of arguments.
# @arg $1 expected count
# @arg $@ remaining args (count-checked against $1)
# @exitcode 0 if remaining arg count equals $1
# @exitcode 1 otherwise
function args::has_num_args() {
  args::check_at_least_1_arg "$@"
  local -r expected="$1"
  shift
  [[ $# -eq ${expected} ]]
}

# @description Return true if called with no arguments.
# @arg $@ caller's arguments
# @exitcode 0 if no args
# @exitcode 1 otherwise
function args::no_args() {
  args::has_num_args 0 "$@"
}

# @description Return true if called with at least the given number of arguments.
# @arg $1 minimum count
# @arg $@ remaining args (count-checked against $1)
# @exitcode 0 if remaining arg count is >= $1
# @exitcode 1 otherwise
function args::has_at_least_num_args() {
  args::check_at_least_1_arg "$@"
  local -r minimum="$1"
  shift
  [[ $# -ge ${minimum} ]]
}

# @description Die if stdin has no data available (i.e., a terminal is attached).
# shellcheck disable=SC2120 # called with no args by callers, but shellcheck can't see all call sites
# @noargs
function args::check_for_stdin() {
  args::check_no_args "$@"
  if [[ -t 0 ]]; then
    log::die 'Expected STDIN'
  fi
}

# @description Return true if stdin has data available (i.e., not a terminal).
# shellcheck disable=SC2120 # called with no args by callers, but shellcheck can't see all call sites
# @noargs
# @exitcode 0 if true
# @exitcode 1 if false
function args::stdin_exists() {
  args::check_no_args "$@"
  ! [[ -t 0 ]]
}

# @description Print help text derived from the file-level shdoc header of the caller (or the given script path).
#   Parses comment lines between the shebang and the first non-comment line for @description, @arg, @noargs,
#   @stdout, @stderr, @exitcode, and @example tags. Multi-line continuations of @description and @example
#   are preserved.
# @arg $1 path Optional script path; defaults to "$0" (the caller).
# @stdout Formatted help text.
# @exitcode 0 always.
# shellcheck disable=SC2120 # called with optional path arg by tests; no-arg invocation valid for runtime use
function args::print_help() {
  args::check_at_most_1_arg "$@"
  local -r script_path="${1:-$0}"
  local -r script_name="${script_path##*/}"

  local description=''
  local -a args_list=()
  local -a exitcodes=()
  local stdout_text=''
  local stderr_text=''
  local -a example_lines=()
  local current_tag=''
  local in_header=0
  local line
  local content

  while IFS= read -r line; do
    if [[ ${line} == '#!'* ]]; then
      in_header=1
      continue
    fi
    if ((!in_header)); then
      continue
    fi
    if strings::is_empty "${line}"; then
      continue
    fi
    if [[ ${line} != '#'* ]]; then
      break
    fi
    if [[ ${line} =~ ^#[[:space:]]*@([a-z]+)[[:space:]]*(.*)$ ]]; then
      current_tag="${BASH_REMATCH[1]}"
      content="${BASH_REMATCH[2]}"
      case "${current_tag}" in
      description) description="${content}" ;;
      arg) args_list+=("${content}") ;;
      exitcode) exitcodes+=("${content}") ;;
      stdout) stdout_text="${content}" ;;
      stderr) stderr_text="${content}" ;;
      example) example_lines=() ;;
      noargs) args_list=() ;;
      esac
    elif [[ ${line} =~ ^#[[:space:]]+(.+)$ ]]; then
      content="${BASH_REMATCH[1]}"
      case "${current_tag}" in
      description) description+=$'\n  '"${content}" ;;
      example) example_lines+=("${content}") ;;
      esac
    fi
  done <"${script_path}"

  printf '%s\n' "${script_name}"
  if strings::is_not_empty "${description}"; then
    printf '\n  %s\n' "${description}"
  fi
  if ((${#args_list[@]} > 0)); then
    printf '\nArguments:\n'
    local arg
    for arg in "${args_list[@]}"; do
      printf '  %s\n' "${arg}"
    done
  fi
  if strings::is_not_empty "${stdout_text}"; then
    printf '\nStdout:\n  %s\n' "${stdout_text}"
  fi
  if strings::is_not_empty "${stderr_text}"; then
    printf '\nStderr:\n  %s\n' "${stderr_text}"
  fi
  if ((${#exitcodes[@]} > 0)); then
    printf '\nExit codes:\n'
    local ec
    for ec in "${exitcodes[@]}"; do
      printf '  %s\n' "${ec}"
    done
  fi
  if ((${#example_lines[@]} > 0)); then
    printf '\nExample:\n'
    local ex
    for ex in "${example_lines[@]}"; do
      printf '  %s\n' "${ex}"
    done
  fi
}

# @description Scan caller's args for `-h`/`--help`; if found, print help via args::print_help and exit 0.
#   Call early in a top-level script, before arg-count guards, so help works even when called with no other args.
# @arg $@ caller's arguments (forwarded verbatim)
# @exitcode 0 if -h/--help found (after printing help)
function args::handle_help_flag() {
  local arg
  for arg in "$@"; do
    case "${arg}" in
    -h | --help)
      # shellcheck disable=SC2119 # intentional no-arg call; print_help defaults to $0
      args::print_help
      exit 0
      ;;
    esac
  done
}
