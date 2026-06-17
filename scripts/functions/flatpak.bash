#!/usr/bin/env bash

# @description Assert that a flatpak application is installed; die if missing.
# @arg $1 id flatpak application id (reverse-DNS form)
# @exitcode 0 application is installed
# @exitcode 1 application is not installed
function flatpak::assert_installed() {
  args::check_exactly_1_arg "$@"
  local -r id="$1"
  commands::assert_executable_exists 'flatpak'
  if ! flatpak info "${id}" &>'/dev/null'; then
    log::die "Flatpak application not installed: ${id}"
  fi
}

# @description Launch a flatpak GUI app detached from the terminal so the shell
#              prompt returns immediately. Asserts the app is installed, then
#              execs via misc::exec_gui (setsid --fork). Does not return.
# @arg $1 id flatpak application id
# @arg $@ args Arguments forwarded verbatim to flatpak run.
# @exitcode 1 application is not installed
function flatpak::exec_gui() {
  args::check_at_least_1_arg "$@"
  local -r id="$1"
  shift
  flatpak::assert_installed "${id}"
  misc::exec_gui flatpak run "${id}" "$@"
}

# @description Launch a flatpak app attached to the terminal (stdio connected,
#              blocks until the app exits). Asserts the app is installed, then
#              execs `flatpak run`. Does not return.
# @arg $1 id flatpak application id
# @arg $@ args Arguments forwarded verbatim to flatpak run.
# @exitcode 1 application is not installed
function flatpak::exec() {
  args::check_at_least_1_arg "$@"
  local -r id="$1"
  shift
  flatpak::assert_installed "${id}"
  exec flatpak run "${id}" "$@"
}
