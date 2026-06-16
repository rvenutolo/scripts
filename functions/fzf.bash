#!/usr/bin/env bash

# @description Read candidate lines from stdin, run `fzf` with the repo-standard
#              flags (`--height=20 --exact --layout=reverse`) plus any extra
#              args, and print the selected line to stdout. The function's exit
#              status mirrors fzf's, so a non-zero status propagates when the
#              user aborts the picker.
# @arg $@ extra fzf args appended verbatim to the standard flag set
# @stdin candidate lines, one per line
# @stdout the selected candidate line
# @exitcode 0 a selection was made
# @exitcode 130 (or other non-zero) the user aborted the picker
function fzf::select() {
  # pass-through: variadic fzf args, no fixed arity
  fzf --height=20 --exact --layout=reverse "$@"
}
