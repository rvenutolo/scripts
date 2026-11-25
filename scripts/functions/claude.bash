#!/usr/bin/env bash

# @description Print the effective Claude Code config dir. An already-set
#   (non-empty) CLAUDE_CONFIG_DIR is an explicit user override and is honored
#   verbatim. Otherwise the value is derived from PWD: at or under
#   ${WORK_PROJECTS_DIR} -> ${XDG_CONFIG_HOME}/claude/work, anywhere else ->
#   ${XDG_CONFIG_HOME}/claude/personal.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
# @stdout the config dir path
function claude::config_dir() {
  args::check_no_args "$@"
  # ${CLAUDE_CONFIG_DIR:-} is not a defensive default for a guaranteed env
  # var: unset is a valid state meaning "no manual override" — the var is
  # intentionally never ambient-set by the profile.
  if strings::is_not_empty "${CLAUDE_CONFIG_DIR:-}"; then
    printf '%s\n' "${CLAUDE_CONFIG_DIR}"
    return
  fi
  if [[ "${PWD}" == "${WORK_PROJECTS_DIR}" || "${PWD}" == "${WORK_PROJECTS_DIR}/"* ]]; then
    printf '%s\n' "${XDG_CONFIG_HOME}/claude/work"
  else
    printf '%s\n' "${XDG_CONFIG_HOME}/claude/personal"
  fi
}

# @description Print the Claude Code projects directory:
#   `$(claude::config_dir)/projects`.
# @noargs
# @stdout the projects directory path
function claude::projects_dir() {
  args::check_no_args "$@"
  printf '%s/projects\n' "$(claude::config_dir)"
}

# @description Print the absolute path of each Claude Code profile config dir --
#   `${XDG_CONFIG_HOME}/claude/personal` and `${XDG_CONFIG_HOME}/claude/work` --
#   one per line, personal first. Only dirs that already exist are printed, so a
#   machine carrying a single profile yields a single line. Unlike
#   `claude::config_dir` this enumerates the fixed profile set rather than
#   selecting one, and deliberately ignores both CLAUDE_CONFIG_DIR and PWD.
# @noargs
# @stdout one existing profile config dir path per line; no output if none exist
function claude::profile_dirs() {
  args::check_no_args "$@"
  local -ar profiles=('personal' 'work')
  local profile profile_dir
  for profile in "${profiles[@]}"; do
    profile_dir="${XDG_CONFIG_HOME}/claude/${profile}"
    if dirs::exists "${profile_dir}"; then
      printf '%s\n' "${profile_dir}"
    fi
  done
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
  jq -rc 'select(.cwd != null)|.cwd' "${jsonl}" > "${tmp}"
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
  jq -rc 'select(.gitBranch != null)|.gitBranch' "${jsonl}" > "${tmp}"
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
  jq -rc 'select(.type=="last-prompt" and .lastPrompt != null)|.lastPrompt|gsub("\n";" ")' "${jsonl}" > "${tmp}"
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
  jq -rc 'select(.type=="last-prompt" and .lastPrompt != null)|.lastPrompt|gsub("\n";" ")' "${jsonl}" > "${tmp}"
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
  if [[ ! "${n}" =~ ^[1-9][0-9]*$ ]]; then
    log::die "count must be a positive integer: ${n}"
  fi
  local tmp
  files::create_temp tmp
  # shellcheck disable=SC2154 # tmp assigned by files::create_temp via nameref
  jq -rc 'select(.type=="last-prompt" and .lastPrompt != null)|.lastPrompt|gsub("\n";" ")' "${jsonl}" > "${tmp}"
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
  claude::session_recent_prompts "${jsonl}" "${n}" > "${recent_tmp}"
  local line
  while read -r line; do
    printf '  - %s\n' "${line}"
  done < "${recent_tmp}"
}

# @description Print the repo root above dir: the nearest dir (dir itself included)
#   holding a `.git` entry, directory or file. Prints nothing outside a repo. Found
#   without asking git, so a git failure (e.g. dubious ownership) cannot pass for
#   "not a repo" and let claude::wrapper_args read a file it never verified.
# @arg $1 dir absolute start directory
# @stdout the repo root, or nothing
function claude::_wrapper_args_repo_root() {
  args::check_exactly_1_arg "$@"
  local dir="$1"
  while true; do
    # -e, not a files::/dirs:: helper: .git is a directory in a clone and a file in
    # a worktree or submodule.
    if [[ -e "${dir}/.git" ]]; then
      printf '%s\n' "${dir}"
      return
    fi
    if [[ "${dir}" == '/' ]]; then
      return
    fi
    dir="$(dirname -- "${dir}")"
  done
}

# @description Print the `.claude/wrapper-args` file claude::wrapper_args applies:
#   the nearest one from start_dir up to and including the repo root, or only
#   start_dir's outside a repo. Prints nothing when there is none.
# @arg $1 start_dir absolute start directory
# @arg $2 root repo root, or an empty string outside a repo
# @stdout the file path, or nothing
function claude::_wrapper_args_find() {
  args::check_exactly_2_args "$@"
  local dir="$1"
  local -r root="$2"
  while true; do
    if files::exists "${dir}/.claude/wrapper-args"; then
      printf '%s\n' "${dir}/.claude/wrapper-args"
      return
    fi
    if strings::is_empty "${root}" || [[ "${dir}" == "${root}" || "${dir}" == '/' ]]; then
      return
    fi
    dir="$(dirname -- "${dir}")"
  done
}

# @description Collect the extra `claude` arguments a project asks for in an untracked
#   `.claude/wrapper-args` file. The file is the nearest one from start_dir up to and
#   including the repo root (a dir holding a `.git` directory or file); outside a repo
#   only start_dir is checked. The file is personal and local-only, so one that git
#   tracks (committed or merely staged) is ignored, as is one whose status git cannot
#   report: a cloned repo must not be able to inject flags.
#
#   Content is one line (newlines count as whitespace). `$VAR` and `${VAR}` expand from
#   the environment via envsubst, which never runs `$(...)` or backticks and also
#   expands inside single quotes. The result is split by xargs, honoring single quotes,
#   double quotes and backslash escapes. An argument that is exactly `~` or starts with
#   `~/` gets `${HOME}` in place of the `~`; a `~` anywhere else stays literal.
#   Expanded values are re-parsed by xargs, so a quote or backslash inside a
#   variable's value is read as syntax.
#
#   Write list-taking claude flags (`--add-dir`, `--allowedTools`, `--mcp-config`,
#   ...) as `--flag=value`. The wrapper places these arguments right before the
#   caller's, and the space-separated form keeps consuming words, so it would
#   swallow the caller's prompt or subcommand.
#
#   Every rejection warns on stderr, naming the file and the reason, and yields no
#   arguments at all, never a partial set: the file is tracked, git cannot answer, a
#   referenced variable is not exported (an unexported shell variable counts as
#   unset, since envsubst sees only the environment), the line does not parse
#   (e.g. an unclosed quote), the file is unreadable, or envsubst is not installed.
#   A bad file never makes this helper fail. The lookup uses the physical path of
#   start_dir, so a symlinked directory resolves to its real repo.
# @arg $1 out_name name of the caller's indexed array to fill (emptied first)
# @arg $2 start_dir absolute directory the lookup starts from, normally ${PWD}
# @stderr a warning for every ignored file
# @exitcode 1 wrong argument count, or out_name is the reserved nameref name
function claude::wrapper_args() {
  args::check_exactly_2_args "$@"
  local -r out_name="$1"
  namerefs::assert_available "${out_name}" '__claude_wrapper_args_ref'
  local -n __claude_wrapper_args_ref="${out_name}"
  __claude_wrapper_args_ref=()
  # The physical path, so a symlinked PWD cannot hide the repo root and skip the
  # tracked check; it also makes a relative start_dir absolute.
  local start_dir
  start_dir="$(cd -P -- "$2" && pwd -P)" # -P: no long-form equivalent

  local root file
  root="$(claude::_wrapper_args_repo_root "${start_dir}")"
  file="$(claude::_wrapper_args_find "${start_dir}" "${root}")"
  if strings::is_empty "${file}"; then
    return
  fi

  if strings::is_not_empty "${root}"; then
    # The file, plus the .claude entry when it is a symlink: git reports a path
    # through a symlink as untracked, so a committed .claude symlink into an
    # untracked directory would otherwise pass.
    local -a check_paths=("${file#"${root}/"}")
    local claude_dir
    claude_dir="$(dirname -- "${file}")"
    if [[ -L "${claude_dir}" ]]; then
      check_paths+=("${claude_dir#"${root}/"}")
    fi
    local check_path git_status
    for check_path in "${check_paths[@]}"; do
      git_status=0
      # The subshell drops inherited GIT_DIR and friends, which would otherwise
      # consult another repo's index.
      (
        git::clear_local_env
        git -C "${root}" ls-files --error-unmatch -- "${check_path}" > '/dev/null' 2>&1 # -C: no long-form equivalent
      ) || git_status=$?
      case "${git_status}" in
        0)
          log::warn "ignoring ${file}: ${check_path} is tracked by git; wrapper args must stay local-only"
          return
          ;;
        1) ;;
        *)
          log::warn "ignoring ${file}: could not verify it is untracked (git exit ${git_status})"
          return
          ;;
      esac
    done
  fi

  if [[ ! -r "${file}" ]]; then
    log::warn "ignoring ${file}: it is not readable"
    return
  fi
  if ! commands::executable_exists envsubst; then
    log::warn "ignoring ${file}: envsubst (gettext) is not installed"
    return
  fi
  local content
  content="$(< "${file}")"
  local names_file
  files::create_temp names_file
  envsubst --variables -- "${content}" > "${names_file}"
  local -a names=()
  mapfile -t names < "${names_file}"
  local name
  for name in "${names[@]}"; do
    if ! printenv -- "${name}" > '/dev/null'; then
      log::warn "ignoring ${file}: variable ${name} is not set in the environment"
      return
    fi
  done

  local expanded_file split_file
  files::create_temp expanded_file
  files::create_temp split_file
  envsubst < "${file}" > "${expanded_file}"
  local xargs_status=0
  xargs --no-run-if-empty --max-args=1 printf '%s\0' < "${expanded_file}" > "${split_file}" 2> '/dev/null' \
    || xargs_status=$?
  if ((xargs_status != 0)); then
    log::warn "ignoring ${file}: could not parse it (unbalanced quote?)"
    return
  fi

  local -a split=()
  mapfile -d '' -t split < "${split_file}"
  local arg
  # shellcheck disable=SC2088 # the quoted tilde is the literal text being matched, not a path
  for arg in "${split[@]}"; do
    case "${arg}" in
      '~') arg="${HOME}" ;;
      '~/'*) arg="${HOME}/${arg#'~/'}" ;;
      *) ;;
    esac
    __claude_wrapper_args_ref+=("${arg}")
  done
}
