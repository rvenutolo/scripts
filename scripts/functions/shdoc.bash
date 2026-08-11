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
# (does not match `^# @`). The literal `main` function is always excluded —
# it is covered by the file-level header per project rule.
# @arg $1 file path to script
# @stdout names of unannotated helper functions, one per line
# @exitcode 0 always (presence of unannotated functions is signaled via stdout)
function shdoc::find_unannotated_functions() {
  args::check_exactly_1_arg "$@"
  local -r file="$1"
  awk '
    /^function [A-Za-z_][A-Za-z0-9_]*\(\)[[:space:]]*\{/ {
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
# word-bounded `TODO`, so `todo` and `TODOS` do not trip it. Content outside the
# header window is ignored — that is what exempts new-script, whose scaffold
# template lives in a heredoc well past its own pragma line.
# @arg $1 file path to script
# @exitcode 0 placeholder text found in the header window
# @exitcode 1 no placeholder text in the header window
function shdoc::header_has_placeholder() {
  args::check_exactly_1_arg "$@"
  local -r file="$1"
  local end_line
  end_line="$(shdoc::_header_end_line "${file}")"
  head --lines="${end_line}" -- "${file}" \
    | gawk '
      /^# @/ { in_tags = 1 }
      in_tags && /^#/ && /\<TODO\>/ { found = 1 }
      END { exit(found ? 0 : 1) }
    '
}
