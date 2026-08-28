#!/usr/bin/env bash

# @description Die when a caller-supplied out-parameter name collides with the nameref a helper
#              binds internally. Bash does not fail on such a collision: `local -n x="x"` prints a
#              "circular name reference" warning to stderr, leaves the variable empty and returns 0,
#              so an out-parameter helper silently hands back nothing while the caller carries on.
#              This guard turns that silent empty result into a loud death naming the reserved name.
#
#              Call it immediately before the `local -n` binding, with the reserved name spelled as
#              a literal on both lines so a desync is visible on sight:
#
#                  local -r out_name="$1"
#                  namerefs::assert_available "${out_name}" '__arrays_diff_first_ref'
#                  local -n __arrays_diff_first_ref="${out_name}"
#
#              The reserved name follows `__<namespace>_<function>_ref`, derived from the enclosing
#              function with `::` replaced by `_`. `.ci/check-nameref-convention` enforces both the
#              derived name and the presence of this guard.
# @arg $1 requested the out-parameter name the caller supplied
# @arg $2 reserved the name the helper binds via `local -n`
# @exitcode 0 the requested name is usable
# @exitcode 1 the requested name is the reserved one
function namerefs::assert_available() {
  args::check_exactly_2_args "$@"
  local -r requested="$1"
  local -r reserved="$2"
  if [[ "${requested}" == "${reserved}" ]]; then
    log::die "out-parameter may not be named '${reserved}': that is the nameref this helper binds"
  fi
}
