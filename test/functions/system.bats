#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/strings.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/misc.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/prompt.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/system.bash"
}

# ---------- require_bash_version ----------

@test "require_bash_version: succeeds on 1 0 (host satisfies)" {
  run system::require_bash_version 1 0
  assert_success
}

@test "require_bash_version: succeeds on host major + minor 0" {
  run system::require_bash_version "${BASH_VERSINFO[0]}" 0
  assert_success
}

@test "require_bash_version: succeeds on host major.minor exactly" {
  run system::require_bash_version "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}"
  assert_success
}

@test "require_bash_version: dies on impossibly large major" {
  run system::require_bash_version 99 0
  assert_failure
  assert_output --partial 'bash 99.0+ required'
}

@test "require_bash_version: dies on host major + impossibly large minor" {
  run system::require_bash_version "${BASH_VERSINFO[0]}" 99
  assert_failure
  assert_output --partial "bash ${BASH_VERSINFO[0]}.99+ required"
}

@test "require_bash_version: dies with no args" {
  run system::require_bash_version
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "require_bash_version: dies with one arg" {
  run system::require_bash_version 4
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "require_bash_version: dies with three args" {
  run system::require_bash_version 4 0 0
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

# ---------- reload_sysctl_conf (deferred) ----------

@test "reload_sysctl_conf: deferred to Phase G" {
  skip 'requires sudo (Phase G)'
}
