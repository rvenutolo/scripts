#!/usr/bin/env bash

# @description Print the Claude Code projects directory: `${CLAUDE_CONFIG_DIR}/projects`.
#   Dies if CLAUDE_CONFIG_DIR is unset or empty.
# @noargs
# @stdout the projects directory path
function claude::projects_dir() {
  args::check_no_args "$@"
  env::assert_var_set 'CLAUDE_CONFIG_DIR'
  printf '%s\n' "${CLAUDE_CONFIG_DIR}/projects"
}

# @description Encode an absolute path into a Claude Code project-dir name by replacing
#   every `/` and `.` with `-` (e.g. `/home/x/.config/y` -> `-home-x--config-y`).
# @arg $1 path absolute path to encode
# @stdout the encoded path
function claude::encode_path() {
  args::check_exactly_1_arg "$@"
  local -r path="$1"
  local encoded="${path//\//-}"
  encoded="${encoded//./-}"
  printf '%s\n' "${encoded}"
}

# @description Print the first `cwd` value recorded in a session jsonl file; empty if none.
# @arg $1 jsonl path to a session jsonl file
# @stdout the first cwd value, or empty string
function claude::session_cwd() {
  args::check_exactly_1_arg "$@"
  local -r jsonl="$1"
  files::assert_exists "${jsonl}"
  local tmp
  files::create_temp tmp
  # shellcheck disable=SC2154 # tmp assigned by files::create_temp via nameref
  jq -rc 'select(.cwd != null)|.cwd' "${jsonl}" >"${tmp}"
  head -1 "${tmp}"
}

# @description Print the first `gitBranch` value recorded in a session jsonl file; empty if none.
# @arg $1 jsonl path to a session jsonl file
# @stdout the first gitBranch value, or empty string
function claude::session_branch() {
  args::check_exactly_1_arg "$@"
  local -r jsonl="$1"
  files::assert_exists "${jsonl}"
  local tmp
  files::create_temp tmp
  # shellcheck disable=SC2154 # tmp assigned by files::create_temp via nameref
  jq -rc 'select(.gitBranch != null)|.gitBranch' "${jsonl}" >"${tmp}"
  head -1 "${tmp}"
}

# @description Print the `lastPrompt` of the FIRST `last-prompt` line in a session jsonl file;
#   empty string if there are no such lines.
# @arg $1 jsonl path to a session jsonl file
# @stdout the first prompt, or empty string
function claude::session_first_prompt() {
  args::check_exactly_1_arg "$@"
  local -r jsonl="$1"
  files::assert_exists "${jsonl}"
  local tmp
  files::create_temp tmp
  # shellcheck disable=SC2154 # tmp assigned by files::create_temp via nameref
  jq -rc 'select(.type=="last-prompt" and .lastPrompt != null)|.lastPrompt' "${jsonl}" >"${tmp}"
  head -1 "${tmp}"
}

# @description Print the `lastPrompt` of the LAST `last-prompt` line in a session jsonl file;
#   empty string if there are no such lines.
# @arg $1 jsonl path to a session jsonl file
# @stdout the last prompt, or empty string
function claude::session_last_prompt() {
  args::check_exactly_1_arg "$@"
  local -r jsonl="$1"
  files::assert_exists "${jsonl}"
  local tmp
  files::create_temp tmp
  # shellcheck disable=SC2154 # tmp assigned by files::create_temp via nameref
  jq -rc 'select(.type=="last-prompt" and .lastPrompt != null)|.lastPrompt' "${jsonl}" >"${tmp}"
  tail -1 "${tmp}"
}
