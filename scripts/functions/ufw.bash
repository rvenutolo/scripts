#!/usr/bin/env bash

# @description Predicate: does ufw already hold the given rule?
# Asks ufw itself with `ufw --dry-run`, so the answer comes from ufw's own rule matching rather than from parsing its
# status table, and works while ufw is inactive. The rule exists only when ufw reports it as existing and would update
# nothing: a rule present for one address family but not the other, or with a different comment, reads as missing.
# `LC_ALL=C` because ufw translates the "Skipping adding existing rule" message. A failing dry-run (malformed rule,
# refused sudo) dies rather than reading as "missing", because errexit is off in a predicate's call tree.
# @arg $@ rule arguments as given to `ufw` (e.g. "allow" "proto" "tcp" "from" "10.0.0.0/8" "port" "22")
# @exitcode 0 if the rule exists
# @exitcode 1 if the rule is missing, or the dry-run failed (after printing ufw's output to stderr)
function ufw::rule_exists() {
  args::check_at_least_1_arg "$@"
  local output
  if ! output="$(sudo env LC_ALL=C ufw --dry-run "$@" 2>&1)"; then
    log::die "ufw --dry-run $* failed: ${output}"
  fi
  [[ "${output}" == *'Skipping adding existing rule'* && ! "${output}" =~ (^|$'\n')'Rules updated' ]]
}

# @description Add a ufw rule. Does not prompt; callers own confirmation.
# @arg $@ rule arguments as given to `ufw` (e.g. "allow" "in" "on" "tailscale0")
# @exitcode 0 on success
# @exitcode 1 if no arguments are given
# @exitcode N ufw's exit status when it fails
function ufw::add_rule() {
  args::check_at_least_1_arg "$@"
  sudo ufw "$@"
}
