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
  jq -rc 'select(.type=="last-prompt" and .lastPrompt != null)|.lastPrompt|gsub("\n";" ")' "${jsonl}" >"${tmp}"
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
  jq -rc 'select(.type=="last-prompt" and .lastPrompt != null)|.lastPrompt|gsub("\n";" ")' "${jsonl}" >"${tmp}"
  tail -1 "${tmp}"
}

# @description Print the `lastPrompt` values of the last <n> `last-prompt` lines in a session
#   jsonl file, in chronological order (oldest of the n first); fewer lines if the session has
#   fewer prompts, empty output if it has none. Each prompt is collapsed to a single line.
# @arg $1 jsonl path to a session jsonl file
# @arg $2 n number of recent prompts to print (positive integer)
# @stdout up to n recent prompts, one per line
# @exitcode 1 if n is not a positive integer
function claude::session_recent_prompts() {
  args::check_exactly_2_args "$@"
  local -r jsonl="$1"
  local -r n="$2"
  files::assert_exists "${jsonl}"
  if [[ ! ${n} =~ ^[1-9][0-9]*$ ]]; then
    log::die "count must be a positive integer: ${n}"
  fi
  local tmp
  files::create_temp tmp
  # shellcheck disable=SC2154 # tmp assigned by files::create_temp via nameref
  jq -rc 'select(.type=="last-prompt" and .lastPrompt != null)|.lastPrompt|gsub("\n";" ")' "${jsonl}" >"${tmp}"
  tail -n "${n}" "${tmp}"
}

# @description Render a human-readable preview of a session for fzf: its first message and its
#   last <n> messages. Intended as the `fzf --preview` command target.
# @arg $1 jsonl path to a session jsonl file
# @arg $2 n number of recent prompts to show (positive integer)
# @stdout a formatted multi-line preview block
# @exitcode 1 if n is not a positive integer
function claude::session_preview() {
  args::check_exactly_2_args "$@"
  local -r jsonl="$1"
  local -r n="$2"
  files::assert_exists "${jsonl}"
  local first
  first="$(claude::session_first_prompt "${jsonl}")"
  if strings::is_empty "${first}"; then
    first='(no prompt)'
  fi
  printf 'First message:\n  %s\n\n' "${first}"
  printf 'Last %s messages:\n' "${n}"
  local recent_tmp
  files::create_temp recent_tmp
  # shellcheck disable=SC2154 # recent_tmp assigned by files::create_temp via nameref
  claude::session_recent_prompts "${jsonl}" "${n}" >"${recent_tmp}"
  local line
  while read -r line; do
    printf '  - %s\n' "${line}"
  done <"${recent_tmp}"
}
