#!/usr/bin/env bats

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/user.bash"
}

# ---------- check_not_root (natural state: EUID != 0) ----------

@test "check_not_root: succeeds when not root" {
  run user::check_not_root
  assert_success
}

@test "check_not_root: dies with args" {
  run user::check_not_root 'extra'
  assert_failure
  assert_output --partial 'Expected no arguments'
}

# ---------- check_is_root (natural state: EUID != 0) ----------

@test "check_is_root: dies when not root" {
  run user::check_is_root
  assert_failure
  assert_output --partial 'Must be root'
}

@test "check_is_root: dies with args" {
  run user::check_is_root 'extra'
  assert_failure
  assert_output --partial 'Expected no arguments'
}

# ---------- root-state branches via unshare --user --map-root-user ----------

# Smoke test that unshare --user --map-root-user actually maps EUID=0 on this host.
# Some hardened kernels disable user namespaces. Skip the root-state tests if so.
unshare_root_works() {
  # shellcheck disable=SC2016 # ${EUID} must expand inside the unshare-spawned bash, not the outer shell
  command -v unshare > /dev/null 2>&1 \
    && [[ "$(unshare --user --map-root-user -- bash -c 'printf %s "${EUID}"' 2> /dev/null)" == '0' ]]
}

@test "check_not_root: dies when EUID == 0 (under unshare)" {
  unshare_root_works || skip 'unshare --user --map-root-user unavailable'
  run unshare --user --map-root-user -- bash -c "
    set -Eeuo pipefail
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/user.bash'
    user::check_not_root
  "
  assert_failure
  assert_output --partial 'Must not be root'
}

@test "check_is_root: succeeds when EUID == 0 (under unshare)" {
  unshare_root_works || skip 'unshare --user --map-root-user unavailable'
  run unshare --user --map-root-user -- bash -c "
    set -Eeuo pipefail
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/user.bash'
    user::check_is_root
  "
  assert_success
}
