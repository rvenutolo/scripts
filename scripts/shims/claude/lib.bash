#!/usr/bin/env bash

# @description Shared logic for the Claude-only pkill/killall PATH shims in this
#              directory. Standalone by necessity: the shims run under whatever
#              userland the host has, and the test suite runs every case with PATH
#              restricted to <shim-dir>:<stub-dir>, where realpath, dirname, grep and
#              date do not exist. Bash builtins only; never source .functions.bash.
#              Sourced by ./pkill and ./killall after each has set SHIM_DIR; the two
#              differ only in their option table and how many patterns they check.

# Process names that, matched as a substring of a lowercased pattern, take the
# whole session down. Lowercase; the check lowercases the pattern to compare.
readonly SHIM_CRITICAL_NAMES=(
  xorg startplasma plasmashell plasma kwin ksmserver kded sddm
  dbus systemd pipewire wireplumber login init
)
readonly SHIM_MIN_PATTERN_LENGTH=4

# @description Return true when the argument list asks for help or version
#              output. Those calls never kill anything, and the shim is a
#              pass-through, so the real binary must answer them.
# @arg $@ args the full argument list
# @exitcode 0 a help/version flag is present
# @exitcode 1 otherwise
function shim::is_help_request() {
  local arg
  for arg in "$@"; do
    case "${arg}" in
      -h | --help | -V | --version) return 0 ;;
    esac
  done
  return 1
}

# @description Fill the named array with the non-option arguments of a
#              pkill/killall-style argument list, skipping option values per the
#              given option table. `--` ends options. `-<digits>` and
#              `-<UPPERCASE...>` (two or more characters) are signal names and take
#              no value. A short cluster takes a value only when its LAST letter is
#              value-taking (`-fs 9`); a value-taking letter with text after it has
#              the value attached (`-s9`, `-sf`).
# @arg $1 out_name name of the array to fill (cleared first)
# @arg $2 value_short letters of short options that take a value, e.g. 'dgGOPstuUFr'
# @arg $3 value_long space-separated long options that take a value
# @arg $@ args the argument list to scan (everything after $3)
function shim::positional_args() {
  local -n _shim_out="$1"
  local -r value_short="$2"
  local -r value_long=" $3 "
  shift 3
  _shim_out=()
  local arg cluster letter
  local -i skip_next=0 i
  while (($# > 0)); do
    arg="$1"
    shift
    if ((skip_next)); then
      skip_next=0
      continue
    fi
    case "${arg}" in
      --)
        _shim_out+=("$@")
        break
        ;;
      --*=*) ;;
      --*)
        if [[ "${value_long}" == *" ${arg} "* ]]; then
          skip_next=1
        fi
        ;;
      -[0-9]* | -[A-Z][A-Z0-9]*) ;;
      -?*)
        cluster="${arg#-}"
        for ((i = 0; i < ${#cluster}; i++)); do
          letter="${cluster:i:1}"
          if [[ "${value_short}" == *"${letter}"* ]]; then
            if ((i == ${#cluster} - 1)); then
              skip_next=1
            fi
            break
          fi
        done
        ;;
      *)
        _shim_out+=("${arg}")
        ;;
    esac
  done
}

# @description Print the refusal to stderr and exit 125. The real binary is
#              never invoked. The message is the product: it names what was
#              refused, why, and both fixes.
# @arg $1 tool shim name, for the message
# @arg $2 reason why the call was refused
# @arg $3 pattern the offending pattern (optional; omitted when none was given)
# @stderr The refusal message.
# @exitcode 125 always
function shim::refuse() {
  local -r tool="$1"
  local -r reason="$2"
  local -r pattern="${3:-}"
  {
    printf '%s: refused: %s\n' "${tool}" "${reason}"
    if [[ -n "${pattern}" ]]; then
      printf "  pattern: '%s'\n" "${pattern}"
    fi
    printf '  This shim guards the Claude process tree; a pattern this broad can take down\n'
    printf '  the session (see scripts/shims/claude/ in the scripts repo).\n'
    # shellcheck disable=SC2016 # single-quoted on purpose: literal text for the user, not an expansion
    printf '  Fix: kill by PID instead -- kill "${pid}" -- or use a longer, more specific pattern.\n'
  } >&2
  exit 125
}

# @description Refuse when the pattern is shorter than SHIM_MIN_PATTERN_LENGTH or
#              its lowercase form contains a session-critical process name.
#              Returns normally otherwise.
# @arg $1 tool shim name, for the message
# @arg $2 pattern pattern or process name to check
# @exitcode 125 the pattern is refused (does not return)
function shim::check_pattern() {
  local -r tool="$1"
  local -r pattern="$2"
  local -r lowered="${pattern,,}"
  if ((${#pattern} < SHIM_MIN_PATTERN_LENGTH)); then
    shim::refuse "${tool}" "pattern shorter than ${SHIM_MIN_PATTERN_LENGTH} characters" "${pattern}"
  fi
  local name
  for name in "${SHIM_CRITICAL_NAMES[@]}"; do
    if [[ "${lowered}" == *"${name}"* ]]; then
      shim::refuse "${tool}" "pattern matches session-critical process '${name}'" "${pattern}"
    fi
  done
}

# @description Print the first executable named $1 on PATH, skipping empty PATH
#              entries (an empty entry means cwd, and a ./pkill must never win),
#              entries that do not resolve, and any entry whose physical path is
#              SHIM_DIR — so the shim never finds itself.
# @arg $1 name executable name
# @stdout Absolute path of the real binary.
# @stderr A not-found message when no real binary exists.
# @exitcode 0 found
# @exitcode 127 no real binary on PATH outside SHIM_DIR
function shim::find_real() {
  local -r name="$1"
  local entry resolved candidate
  local -a entries
  # IFS scoped to the read: the script-wide IFS has no ':' in it.
  IFS=':' read -r -a entries <<< "${PATH}"
  for entry in "${entries[@]}"; do
    if [[ -z "${entry}" ]]; then
      continue
    fi
    resolved="$(cd -P -- "${entry}" 2> /dev/null && pwd -P)" || continue
    if [[ "${resolved}" == "${SHIM_DIR}" ]]; then
      continue
    fi
    candidate="${resolved}/${name}"
    if [[ -f "${candidate}" && -x "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  printf '%s: real binary not found on PATH (excluding shim dir %s)\n' "${name}" "${SHIM_DIR}" >&2
  return 127
}
