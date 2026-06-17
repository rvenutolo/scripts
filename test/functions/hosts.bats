#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${REPO_DIR}/test/test_helper/path_shim.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/hosts.bash"

  export PERSONAL_DESKTOP_HOSTNAME='fixture-desktop'
  export PERSONAL_LAPTOP_HOSTNAME='fixture-laptop'
  export WORK_LAPTOP_HOSTNAME='fixture-work'
}

# Helper: install a hostname shim that prints the given value.
set_hostname() {
  path_shim::add 'hostname' "#!/usr/bin/env bash
printf '%s\\n' '$1'"
}

# ---------- is_personal ----------

@test "is_personal: matches desktop hostname" {
  set_hostname 'fixture-desktop'
  run hosts::is_personal
  assert_success
}

@test "is_personal: matches laptop hostname" {
  set_hostname 'fixture-laptop'
  run hosts::is_personal
  assert_success
}

@test "is_personal: does not match work hostname" {
  set_hostname 'fixture-work'
  run hosts::is_personal
  assert_failure
}

@test "is_personal: does not match unknown hostname" {
  set_hostname 'random-server'
  run hosts::is_personal
  assert_failure
}

@test "is_personal: dies with args" {
  set_hostname 'fixture-desktop'
  run hosts::is_personal 'extra'
  assert_failure
  assert_output --partial 'Expected no arguments'
}

# ---------- is_work ----------

@test "is_work: matches work hostname" {
  set_hostname 'fixture-work'
  run hosts::is_work
  assert_success
}

@test "is_work: does not match desktop hostname" {
  set_hostname 'fixture-desktop'
  run hosts::is_work
  assert_failure
}

@test "is_work: does not match laptop hostname" {
  set_hostname 'fixture-laptop'
  run hosts::is_work
  assert_failure
}

@test "is_work: does not match unknown hostname" {
  set_hostname 'random-host'
  run hosts::is_work
  assert_failure
}

# ---------- is_desktop ----------

@test "is_desktop: matches desktop hostname" {
  set_hostname 'fixture-desktop'
  run hosts::is_desktop
  assert_success
}

@test "is_desktop: does not match laptop hostname" {
  set_hostname 'fixture-laptop'
  run hosts::is_desktop
  assert_failure
}

@test "is_desktop: does not match work hostname" {
  set_hostname 'fixture-work'
  run hosts::is_desktop
  assert_failure
}

# ---------- is_laptop ----------

@test "is_laptop: matches personal laptop hostname" {
  set_hostname 'fixture-laptop'
  run hosts::is_laptop
  assert_success
}

@test "is_laptop: matches work laptop hostname" {
  set_hostname 'fixture-work'
  run hosts::is_laptop
  assert_success
}

@test "is_laptop: does not match desktop hostname" {
  set_hostname 'fixture-desktop'
  run hosts::is_laptop
  assert_failure
}

@test "is_laptop: does not match unknown hostname" {
  set_hostname 'random-host'
  run hosts::is_laptop
  assert_failure
}

# ---------- is_server ----------

@test "is_server: matches unknown hostname (anything not personal/work)" {
  set_hostname 'random-server'
  run hosts::is_server
  assert_success
}

@test "is_server: does not match desktop hostname" {
  set_hostname 'fixture-desktop'
  run hosts::is_server
  assert_failure
}

@test "is_server: does not match personal laptop hostname" {
  set_hostname 'fixture-laptop'
  run hosts::is_server
  assert_failure
}

@test "is_server: does not match work hostname" {
  set_hostname 'fixture-work'
  run hosts::is_server
  assert_failure
}
