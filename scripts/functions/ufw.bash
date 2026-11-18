#!/usr/bin/env bash

# @description Predicate: does ufw already hold the given rule?
# Asks ufw itself with `ufw --dry-run`, so the answer comes from ufw's own rule matching rather than from parsing its
# status table, and works while ufw is inactive. The rule exists only when ufw reports it as existing and would update
# nothing: a rule present for one address family but not the other, or with a different comment, reads as missing.
# `LC_ALL=C` with `LANGUAGE` unset because ufw translates the "Skipping adding/inserting existing rule" messages, and
# Python's gettext reads `LANGUAGE` before `LC_ALL`. A failing dry-run (malformed rule, refused sudo) exits the calling
# script via `log::die` rather than reading as "missing", because errexit is off in a predicate's call tree.
# Insert-form rules ("insert N …", "prepend …") are accepted, with one limit from ufw itself: on insert, ufw reports an
# existing rule when any rule matches apart from its action, log type or comment, so an insert-form check cannot tell
# rules apart by those.
# @arg $@ rule arguments as given to `ufw` (e.g. "allow" "proto" "tcp" "from" "10.0.0.0/8" "port" "22")
# @exitcode 0 if the rule exists
# @exitcode 1 if the rule is missing
function ufw::rule_exists() {
  args::check_at_least_1_arg "$@"
  local output
  if ! output="$(sudo env --unset=LANGUAGE LC_ALL=C ufw --dry-run "$@" 2>&1)"; then
    log::die "ufw --dry-run $* failed: ${output}"
  fi
  [[ "${output}" =~ 'Skipping '(adding|inserting)' existing rule' && ! "${output}" =~ (^|$'\n')'Rules updated' ]]
}

# @description Predicate: does ufw know an application profile by this name?
# Asks `ufw app list`, so the answer covers every file under /etc/ufw/applications.d and uses ufw's own
# case-insensitive name matching. A rule naming an unknown profile is a ufw error, so callers check this before passing
# a profile name to `ufw::rule_exists`. Runs in the C locale with `LANGUAGE` unset so the header line is untranslated.
# A failing `ufw app list` exits the calling script via `log::die` rather than reading as "unknown".
# @arg $1 profile name (e.g. "OpenSSH")
# @exitcode 0 if ufw lists the profile
# @exitcode 1 if it does not
function ufw::app_profile_exists() {
  args::check_exactly_1_arg "$@"
  local -r name="$1"
  local output
  if ! output="$(sudo env --unset=LANGUAGE LC_ALL=C ufw app list 2>&1)"; then
    log::die "ufw app list failed: ${output}"
  fi
  # ufw prints a header line, then each profile name on its own line indented by two spaces, so a match must sit
  # between a newline and the end of a line; the header can never match.
  [[ "${output,,}"$'\n' == *$'\n  '"${name,,}"$'\n'* ]]
}

# @description Predicate: is ufw enabled (set to start at boot)?
# Reads `ENABLED` from /etc/ufw/ufw.conf, which is world-readable, so no sudo is needed. The file is read by sourcing
# it, and the value compared case-insensitively because ufw lowercases it. ufw's own parser differs on lines it would
# skip: a single-quoted value, a trailing comment or an indented line reads as set here but not to ufw.
# @noargs
# @exitcode 0 if enabled
# @exitcode 1 if not enabled, or /etc/ufw/ufw.conf does not exist (the script exits via `log::die`)
function ufw::is_enabled() {
  args::check_no_args "$@"
  files::assert_exists '/etc/ufw/ufw.conf'
  local enabled
  # shellcheck disable=SC1091 # /etc/ufw/ufw.conf is a runtime path, not statically followable
  enabled="$(source '/etc/ufw/ufw.conf' && printf '%s' "${ENABLED:-}")"
  [[ "${enabled,,}" == 'yes' ]]
}

# @description Print whether the ufw firewall is running right now: active or inactive.
# Distinct from `ufw::is_enabled`, which is only the start-at-boot flag: the flag can be set while the firewall is down
# (failed unit, `systemctl stop ufw`, flushed iptables). A producer rather than a predicate, so a failing `ufw status`
# dies instead of reading as "inactive". Runs in the C locale with `LANGUAGE` unset, as `ufw::rule_exists` does, so the
# status line is untranslated.
# @noargs
# @stdout active or inactive
# @exitcode 0 on success
# @exitcode 1 if `ufw status` fails or prints an unrecognized status line
function ufw::status() {
  args::check_no_args "$@"
  local output
  if ! output="$(sudo env --unset=LANGUAGE LC_ALL=C ufw status 2>&1)"; then
    log::die "ufw status failed: ${output}"
  fi
  case "${output%%$'\n'*}" in
    'Status: active') printf 'active\n' ;;
    'Status: inactive') printf 'inactive\n' ;;
    *) log::die "Unrecognized ufw status output: ${output}" ;;
  esac
}

# @description Print ufw's default policy for a direction as ufw names it: deny, reject or allow.
# Reads /etc/default/ufw, which is world-readable and holds the policy whether or not ufw is active. The file is read
# by sourcing it, and the value compared case-insensitively because ufw lowercases it. ufw's own parser differs in two
# ways: it skips single-quoted, trailing-comment and indented lines, and a policy key in /etc/ufw/ufw.conf overrides
# this file; neither is reproduced here.
# @arg $1 direction: incoming, outgoing or routed
# @stdout deny, reject or allow
# @exitcode 0 on success
# @exitcode 1 on an unknown direction, a missing /etc/default/ufw, or an unset or unrecognized policy value
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
  files::assert_exists '/etc/default/ufw'
  local value
  # shellcheck disable=SC1091 # /etc/default/ufw is a runtime path, not statically followable
  value="$(source '/etc/default/ufw' && printf '%s' "${!var_name:-}")"
  case "${value^^}" in
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
