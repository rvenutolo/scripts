#!/usr/bin/env bash

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
  end_line="$({ grep --line-number --max-count=1 --extended-regexp '^set -Eeuo pipefail' "${file}" || true; } \
    | cut --delimiter=: --fields=1)"
  if strings::is_blank "${end_line}"; then
    end_line=30
  fi
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
  gawk '
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
