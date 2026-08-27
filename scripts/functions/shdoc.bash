#!/usr/bin/env bash

# @description Print the last line number of a script's file-level shdoc header
# window. The window runs from the shebang to the first `set -Eeuo pipefail`
# line; standalone misc/ scripts that omit that pragma fall back to 30 lines.
# Shared by shdoc::file_has_description and shdoc::header_has_placeholder so
# the two cannot drift apart.
# @arg $1 file path to script
# @stdout The header window's end line number.
function shdoc::_header_end_line() {
  args::check_exactly_1_arg "$@"
  local -r file="$1"
  local end_line
  end_line="$({ grep --line-number --max-count=1 --extended-regexp '^set -Eeuo pipefail' "${file}" || true; } \
    | cut --delimiter=: --fields=1)"
  if strings::is_blank "${end_line}"; then
    end_line=30
  fi
  printf '%s\n' "${end_line}"
}

# @description Return true if the given script file carries an `# @description`
# shdoc tag in its file-level header — i.e. somewhere between the shebang line
# and either the first `set -Eeuo pipefail` line or, for standalone misc/
# scripts that omit that pragma, within the first 30 lines.
# @arg $1 file path to script
# @exitcode 0 if a `# @description` line is found in the header window
# @exitcode 1 otherwise
function shdoc::file_has_description() {
  args::check_exactly_1_arg "$@"
  local -r file="$1"
  local end_line
  end_line="$(shdoc::_header_end_line "${file}")"
  head --lines="${end_line}" -- "${file}" \
    | grep --quiet --extended-regexp '^# @description( |$)'
}

# @description Scan a script file for top-level helper function definitions of
# the form `function NAME() {` and print the names of any whose immediately
# preceding non-blank, non-shellcheck-directive line is NOT a shdoc tag line
# (does not match `^# @`). Names may be namespaced with `::`, which every
# function in functions/*.bash is; omitting the colon from the name class would
# make the library arm of check-shdoc-headers match nothing at all. The literal
# `main` function is always excluded — it is covered by the file-level header per
# project rule.
# @arg $1 file path to script
# @stdout names of unannotated helper functions, one per line
# @exitcode 0 always (presence of unannotated functions is signaled via stdout)
function shdoc::find_unannotated_functions() {
  args::check_exactly_1_arg "$@"
  local -r file="$1"
  awk '
    /^function [A-Za-z_][A-Za-z0-9_:]*\(\)[[:space:]]*\{/ {
      name = $2
      sub(/\(\).*$/, "", name)
      if (name == "main") { next }
      i = NR - 1
      # Skip shellcheck directives; a blank line terminates the scan (no adjacent annotation)
      while (i >= 1 && lines[i] ~ /^# shellcheck /) { i-- }
      if (i < 1 || lines[i] !~ /^# @/) {
        print name
      }
    }
    { lines[NR] = $0 }
  ' "${file}"
}

# @description Return true if a script's file-level shdoc header contains
# placeholder text. Scanning starts at the first `# @` tag line inside the
# header window and covers every comment line from there on, so tag bodies and
# their indented continuations are both checked. The match is a case-sensitive,
# word-bounded `TODO`; a backtick-quoted one is prose about the token and is
# allowed, so `todo`, `TODOS`, and `` `TODO` `` do not trip it. The pattern is
# shared with shdoc::find_placeholder_functions via
# shdoc::_placeholder_gawk_pattern. Content outside the header window is
# ignored — that is what exempts new-script, whose scaffold template lives in a
# heredoc well past its own pragma line.
# @arg $1 file path to script
# @exitcode 0 placeholder text found in the header window
# @exitcode 1 no placeholder text in the header window
function shdoc::header_has_placeholder() {
  args::check_exactly_1_arg "$@"
  local -r file="$1"
  local end_line
  end_line="$(shdoc::_header_end_line "${file}")"
  local pattern
  # shellcheck disable=SC2119 # intentional no-arg call; the helper takes none
  pattern="$(shdoc::_placeholder_gawk_pattern)"
  head --lines="${end_line}" -- "${file}" \
    | gawk --assign pattern="${pattern}" '
      /^# @/ { in_tags = 1 }
      in_tags && /^#/ && $0 ~ pattern { found = 1 }
      END { exit(found ? 0 : 1) }
    '
}

# @description Print the gawk-compatible ERE that matches placeholder text in an
# shdoc annotation. A bare, case-sensitive, word-bounded `TODO` is a placeholder;
# a backtick-quoted one is prose about the token and is deliberately allowed, so
# that helpers documenting this very rule can name it. Underscore counts as a word
# character, so `TODO_MARKER` is not a placeholder either. Defined once and shared
# by shdoc::header_has_placeholder and shdoc::find_placeholder_functions so the
# file-level and per-function checks cannot drift apart, the same reason
# shdoc::_header_end_line is shared.
# @noargs
# @stdout The regular expression.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
function shdoc::_placeholder_gawk_pattern() {
  args::check_no_args "$@"
  # shellcheck disable=SC2016 # the $ is a regex end-of-string anchor, not a shell expansion
  printf '%s\n' '(^|[^`[:alnum:]_])TODO([^`[:alnum:]_]|$)'
}

# @description Scan a script or library file for top-level function definitions of
# the form `function NAME() {` and print the names of any whose contiguous
# preceding comment block contains placeholder text, per
# shdoc::_placeholder_gawk_pattern. The block is every unbroken comment line
# immediately above the definition; a blank or non-comment line ends it, so a
# detached note further up the file is not attributed to the function. Applies to
# both library files and top-level scripts: a helper inside a top-level script has
# an annotation block too, and scanning only the file-level header would miss it.
# The literal `main` function is excluded, mirroring
# shdoc::find_unannotated_functions so both helpers select functions identically.
# @arg $1 file path to script or library file
# @stdout names of functions whose annotation carries placeholder text, one per line
# @exitcode 0 always (presence of placeholders is signaled via stdout)
function shdoc::find_placeholder_functions() {
  args::check_exactly_1_arg "$@"
  local -r file="$1"
  local pattern
  # shellcheck disable=SC2119 # intentional no-arg call; the helper takes none
  pattern="$(shdoc::_placeholder_gawk_pattern)"
  gawk --assign pattern="${pattern}" '
    /^function [A-Za-z_][A-Za-z0-9_:]*\(\)[[:space:]]*\{/ {
      name = $2
      sub(/\(\).*$/, "", name)
      if (name == "main") { next }
      i = NR - 1
      while (i >= 1 && lines[i] ~ /^#/) {
        if (lines[i] ~ pattern) {
          print name
          break
        }
        i--
      }
    }
    { lines[NR] = $0 }
  ' "${file}"
}
