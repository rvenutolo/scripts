#!/usr/bin/env bash

# @description Initialize SDKMAN for the calling subshell so the `sdk` function is available.
#   Shell options and traps are not function-scoped, so everything this does lands in the caller.
#   That is the point — but it also means it MUST be called from inside a `( ... )` subshell, or
#   the strict-mode relaxation leaks into the rest of the script. It dies rather than allow that.
#
#   Typical use:
#
#     # Subshell required: sdkman::init relaxes strict mode, which must not leak past the sdk calls.
#     (
#       sdkman::init
#       sdkman_jdks::get_available_tem_jdk_major_versions
#     )
#
# @noargs
# @exitcode 0 SDKMAN initialized in the calling subshell
# @exitcode 1 called outside a subshell
function sdkman::init() {
  args::check_no_args "$@"
  # BASHPID tracks the current subshell; $$ stays the top-level shell's pid. Equal means the
  # caller is at top level, where relaxing strict mode would silently apply to the whole script.
  if [[ "${BASHPID}" == "$$" ]]; then
    log::die 'sdkman::init must be called from inside a subshell'
  fi
  # SDKMAN's own code references unbound variables (SDKMAN_OFFLINE_MODE among them) and uses
  # non-zero exit status for non-error conditions, so both set -u and the ERR trap have to go.
  # The ERR trap is inherited here via set -E, hence detaching it explicitly.
  set +u
  trap - ERR
  # sdkman-init.sh sources bash completion (sdkman_auto_complete=true in etc/config), which calls
  # the `complete` builtin at source time. Under a non-interactive shell `complete` can be
  # unavailable, exiting 127 and aborting the whole run via inherited errexit. Stub it as a no-op
  # — completion is useless in a script.
  # shellcheck disable=SC2329 # invoked indirectly by the sourced sdkman-init.sh
  function complete() { :; }
  # shellcheck disable=SC1091 # sdkman-init.sh path is dynamic via SDKMAN_DIR env var
  source "${SDKMAN_DIR}/bin/sdkman-init.sh"
}

# @description Strip ANSI escape codes and blank lines from stdin (used to clean sdk command output).
# Output: stdout — cleaned text
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman::clean_output() {
  args::check_no_args "$@"
  args::check_for_stdin
  text::remove_ansi | text::remove_empty_lines
}

# @description Refresh SDKMAN metadata (runs 'sdk update' and cleans output).
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman::update_metadata() {
  args::check_no_args "$@"
  sdk update | sdkman::clean_output
}

# @description Print the path of the nearest `.sdkmanrc` file at or above a directory.
# Walks from the given directory up to `/` and prints the first `.sdkmanrc` found. SDKMAN's own
# auto_env consults only the directory being entered, so a build started in a submodule — or in
# any non-interactive shell — sees no pin at all; this is what recovers it.
# @arg $1 start_dir directory to start the upward search from
# @stdout path of the nearest `.sdkmanrc`, or nothing when no ancestor holds one
# @exitcode 0 always — "none found" is signalled by empty stdout, never a non-zero status
function sdkman::find_sdkmanrc_file() {
  args::check_exactly_1_arg "$@"
  local -r start_dir="$1"
  local dir="${start_dir}"
  while true; do
    if files::exists "${dir}/.sdkmanrc"; then
      printf '%s\n' "${dir}/.sdkmanrc"
      return 0
    fi
    # `dirname /` is `/` and `dirname .` is `.`, so both are fixed points that would spin forever.
    case "${dir}" in
      / | .)
        return 0
        ;;
    esac
    dir="$(dirname -- "${dir}")"
  done
}

# @description Print the value assigned to a key in an `.sdkmanrc` file.
# Tolerant of what a hand-edited file picks up: CRLF line endings, blank lines, whole-line and
# trailing `#` comments, and whitespace around the key, the `=`, and the value. A later assignment
# of the same key wins, matching how a shell reading the file would resolve it.
# Uses `awk -v` (not `--assign`) because mawk — the default awk on Debian/Ubuntu — rejects the long form.
# @arg $1 sdkmanrc_file path to the `.sdkmanrc` file
# @arg $2 key candidate name to look up (e.g. `java`)
# @stdout the assigned value, or nothing when the key is absent or assigned an empty value
# @exitcode 0 always — "absent" is signalled by empty stdout, never a non-zero status
# @exitcode 1 the given file does not exist
function sdkman::get_sdkmanrc_file_value() {
  args::check_exactly_2_args "$@"
  local -r sdkmanrc_file="$1"
  local -r key="$2"
  files::assert_exists "${sdkmanrc_file}"
  awk -v "key=${key}" '
    { sub(/\r$/, "") }
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      value = $0
      sub("^[[:space:]]*" key "[[:space:]]*=[[:space:]]*", "", value)
      sub("[[:space:]]*#.*$", "", value)
      sub("[[:space:]]+$", "", value)
      if (value != "") { result = value }
    }
    END { if (result != "") { print result } }
  ' "${sdkmanrc_file}"
}

# @description Resolve the JDK pinned by the nearest `.sdkmanrc` to an absolute `JAVA_HOME` path.
# Prints nothing — a deliberate no-op — when no ancestor holds an `.sdkmanrc`, when that file
# declares no `java=` key, or when the pinned JDK is not installed. Warning rather than failing on
# an uninstalled pin is deliberate: pins go stale (that is what `sdkman::rewrite_sdkmanrc_file_java_version`
# exists for), and a wrapper that refuses to run Maven over a stale pin is worse than one that
# falls back to the inherited JDK and says so.
# @arg $1 start_dir directory to start the upward `.sdkmanrc` search from
# @stdout absolute path of the pinned JDK's SDKMAN candidate directory, or nothing
# @stderr a `log::warn` line when the pinned JDK is not installed
# @exitcode 0 always — "nothing to apply" is signalled by empty stdout, never a non-zero status
function sdkman::sdkmanrc_java_home() {
  args::check_exactly_1_arg "$@"
  local -r start_dir="$1"
  local sdkmanrc_file
  sdkmanrc_file="$(sdkman::find_sdkmanrc_file "${start_dir}")"
  readonly sdkmanrc_file
  if strings::is_empty "${sdkmanrc_file}"; then
    return 0
  fi
  local java_version
  java_version="$(sdkman::get_sdkmanrc_file_value "${sdkmanrc_file}" 'java')"
  readonly java_version
  if strings::is_empty "${java_version}"; then
    return 0
  fi
  local -r java_home="${SDKMAN_DIR}/candidates/java/${java_version}"
  if ! dirs::exists "${java_home}"; then
    log::warn "${sdkmanrc_file} pins java=${java_version}, which is not installed - leaving JAVA_HOME unchanged"
    return 0
  fi
  printf '%s\n' "${java_home}"
}

# @description Print the java artifact ID declared in an .sdkmanrc file.
# Output: stdout — artifact ID string (e.g. "21.0.3-tem")
# @arg $1 .sdkmanrc file path
function sdkman::get_sdkmanrc_file_java_artifact_id() {
  args::check_exactly_1_arg "$@"
  local -r sdkmanrc_file="$1"
  files::assert_exists "${sdkmanrc_file}"
  sed --quiet 's/^java=\(.*\)/\1/p' "${sdkmanrc_file}"
}

# @description Overwrite the java artifact ID in an .sdkmanrc file.
# @arg $1 .sdkmanrc file path
# @arg $2 new artifact ID (e.g. "21.0.3-tem")
function sdkman::overwrite_sdkmanrc_file_java_artifact_id() {
  args::check_exactly_2_args "$@"
  local -r sdkmanrc_file="$1"
  local -r artifact_id="$2"
  files::assert_exists "${sdkmanrc_file}"
  sed --in-place --expression "s/^java=.*/java=${artifact_id}/" "${sdkmanrc_file}"
}

# @description Update the java entry in an .sdkmanrc file to the latest installed Temurin JDK for the same major version.
# No-ops if the currently declared artifact is already installed.
# @arg $1 .sdkmanrc file path
function sdkman::rewrite_sdkmanrc_file_java_version() {
  args::check_exactly_1_arg "$@"
  local -r sdkmanrc_file="$1"
  files::assert_exists "${sdkmanrc_file}"
  local current_java_artifact_id
  current_java_artifact_id="$(sdkman::get_sdkmanrc_file_java_artifact_id "${sdkmanrc_file}")"
  readonly current_java_artifact_id
  if sdkman_jdks::is_tem_jdk_artifact_installed "${current_java_artifact_id}"; then
    return 0
  fi
  local major_version
  major_version="$(sdkman_jdks::get_jdk_major_version "${current_java_artifact_id}")"
  readonly major_version
  local new_java_artifact_id
  new_java_artifact_id="$(
    sdkman_jdks::get_latest_installed_tem_jdk_artifact_id_for_major_version "${major_version}"
  )"
  readonly new_java_artifact_id
  sdkman::overwrite_sdkmanrc_file_java_artifact_id "${sdkmanrc_file}" "${new_java_artifact_id}"
}

# @description Find and print the paths of all .sdkmanrc files under $HOME.
# Output: stdout — sorted list of .sdkmanrc file paths, one per line
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman::list_all_sdkmanrc_files() {
  args::check_no_args "$@"
  find "${HOME}" -type 'd' \( ! -readable -o ! -executable \) -prune -o -type 'f' -name '.sdkmanrc' -print | sort
}

# @description Update the java entry in every .sdkmanrc file found under $HOME.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman::rewrite_sdkmanrc_file_java_versions() {
  args::check_no_args "$@"
  local -a sdkmanrc_files
  local sdkmanrc_files_tmp
  files::create_temp sdkmanrc_files_tmp
  sdkman::list_all_sdkmanrc_files > "${sdkmanrc_files_tmp}"
  mapfile -t sdkmanrc_files < "${sdkmanrc_files_tmp}"
  for file in "${sdkmanrc_files[@]}"; do
    sdkman::rewrite_sdkmanrc_file_java_version "${file}"
  done
}
