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

# @description Predicate: is ufw enabled (set to start at boot)?
# Reads `ENABLED` from /etc/ufw/ufw.conf, which is world-readable, so no sudo is needed.
# @noargs
# @exitcode 0 if enabled
# @exitcode 1 otherwise
function ufw::is_enabled() {
  args::check_no_args "$@"
  local enabled
  # shellcheck disable=SC1091 # /etc/ufw/ufw.conf is a runtime path, not statically followable
  enabled="$(source '/etc/ufw/ufw.conf' && printf '%s' "${ENABLED:-}")"
  [[ "${enabled}" == 'yes' ]]
}

# @description Print whether the ufw firewall is running right now: active or inactive.
# Distinct from `ufw::is_enabled`, which is only the start-at-boot flag: the flag can be set while the firewall is down
# (failed unit, `systemctl stop ufw`, flushed iptables). A producer rather than a predicate, so a failing `ufw status`
# dies instead of reading as "inactive".
# @noargs
# @stdout active or inactive
# @exitcode 0 on success
# @exitcode 1 if `ufw status` fails or prints an unrecognized status line
function ufw::status() {
  args::check_no_args "$@"
  local output
  if ! output="$(sudo env LC_ALL=C ufw status 2>&1)"; then
    log::die "ufw status failed: ${output}"
  fi
  case "${output%%$'\n'*}" in
    'Status: active') printf 'active\n' ;;
    'Status: inactive') printf 'inactive\n' ;;
    *) log::die "Unrecognized ufw status output: ${output}" ;;
  esac
}

# @description Print ufw's default policy for a direction as ufw names it: deny, reject or allow.
# Reads /etc/default/ufw, which is world-readable and holds the policy whether or not ufw is active.
# @arg $1 direction: incoming, outgoing or routed
# @stdout deny, reject or allow
# @exitcode 0 on success
# @exitcode 1 on an unknown direction, or an unset or unrecognized policy value
function ufw::default_policy() {
  args::check_exactly_1_arg "$@"
  local -r direction="$1"
  local var_name
  case "${direction}" in
    incoming) var_name='DEFAULT_INPUT_POLICY' ;;
    outgoing) var_name='DEFAULT_OUTPUT_POLICY' ;;
    routed) var_name='DEFAULT_FORWARD_POLICY' ;;
    *) log::die "Unknown ufw policy direction: ${direction}" ;;
  esac
  readonly var_name
  local value
  # shellcheck disable=SC1091 # /etc/default/ufw is a runtime path, not statically followable
  value="$(source '/etc/default/ufw' && printf '%s' "${!var_name:-}")"
  case "${value}" in
    DROP) printf 'deny\n' ;;
    REJECT) printf 'reject\n' ;;
    ACCEPT) printf 'allow\n' ;;
    *) log::die "Unrecognized ${var_name} in /etc/default/ufw: '${value}'" ;;
  esac
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
