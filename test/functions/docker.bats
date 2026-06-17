#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  # shellcheck disable=SC1091
  source "${REPO_DIR}/test/test_helper/cli_shim.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/strings.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/docker.bash"
}

# Custom branching docker shim — branches on subcommand.
# install_branching_docker <ps_qid> <inspect_status>
install_branching_docker() {
  local -r ps_qid="$1"
  local -r status="$2"
  path_shim::add docker "$(
    cat << EOF
#!/usr/bin/env bash
case "\$1" in
  ps) printf '%s\n' '${ps_qid}' ;;
  container)
    printf '%s\n' '${status}'
    ;;
  network)
    case "\$2" in
      inspect) exit 1 ;;
      create) printf 'created\n' ;;
    esac
    ;;
  *) exit 1 ;;
esac
EOF
  )"
}

# ---------- container_is_running ----------

@test "container_is_running: true when ps returns id and status=running" {
  install_branching_docker 'abc123' 'running'
  run docker::container_is_running mycontainer
  assert_success
}

@test "container_is_running: false when ps returns empty" {
  install_branching_docker '' 'running'
  run docker::container_is_running mycontainer
  assert_failure
}

@test "container_is_running: false when status != running" {
  install_branching_docker 'abc123' 'exited'
  run docker::container_is_running mycontainer
  assert_failure
}

@test "container_is_running: dies with no args" {
  run docker::container_is_running
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "container_is_running: dies with too many args" {
  run docker::container_is_running a b
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- wait_for_healthy_container ----------

@test "wait_for_healthy_container: returns once status reaches healthy" {
  cli_shim::record_stateful docker 'starting' 'starting' 'healthy'
  run docker::wait_for_healthy_container mycontainer
  assert_success
}

@test "wait_for_healthy_container: dies on timeout" {
  cli_shim::record_stateful docker 'starting'
  run docker::wait_for_healthy_container mycontainer 0
  assert_failure
  assert_output --partial 'did not become healthy'
}

@test "wait_for_healthy_container: dies with no args" {
  run docker::wait_for_healthy_container
  assert_failure
  assert_output --partial 'Expected at least 1 argument'
}

@test "wait_for_healthy_container: dies with too many args" {
  run docker::wait_for_healthy_container a b c
  assert_failure
  assert_output --partial 'Expected at most 2 arguments'
}

# ---------- create_network ----------

@test "create_network: creates network when inspect fails" {
  install_branching_docker '' ''
  run docker::create_network mynet
  assert_success
  assert_output --partial 'Creating mynet network'
  assert_output --partial 'Created mynet network'
}

@test "create_network: no-op when network exists" {
  path_shim::add docker "$(
    cat << 'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  'network inspect') exit 0 ;;
  *) exit 1 ;;
esac
EOF
  )"
  run docker::create_network mynet
  assert_success
  refute_output --partial 'Creating'
}

@test "create_network: dies with no args" {
  run docker::create_network
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "create_network: dies with too many args" {
  run docker::create_network a b
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}
