#!/usr/bin/env bash

# Return true if the named Docker container exists and its status is 'running'.
# $1 = container name
function docker::container_is_running() {
  args::check_exactly_1_arg "$@"
  strings::is_not_empty "$(docker ps --quiet --filter "name=^$1\$")" \
    && [[ "$(docker container inspect --format '{{.State.Status}}' "$1")" == 'running' ]]
}

# Block until the named Docker container reports a health status of 'healthy'.
# Optional second arg caps how long to wait; unset means wait forever.
# $1 = container name
# $2 = optional timeout in seconds (default: no timeout)
function docker::wait_for_healthy_container() {
  args::check_at_least_1_arg "$@"
  args::check_at_most_2_args "$@"
  local -r container="$1"
  # 99999999 seconds is ~3 years — effectively "no timeout"
  local -r timeout_seconds="${2:-99999999}"
  log::log "Waiting for ${container} to be healthy"
  local -r start="${SECONDS}"
  until [[ "$(docker inspect --format '{{.State.Health.Status}}' "${container}")" == 'healthy' ]]; do
    if ((SECONDS - start >= timeout_seconds)); then
      log::die "${container} did not become healthy within ${timeout_seconds}s"
    fi
    sleep 0.1
  done
}

# Create a Docker network with the given name if one does not already exist.
# $1 = docker network name
function docker::create_network() {
  args::check_exactly_1_arg "$@"
  if ! docker network inspect "$1" &> '/dev/null'; then
    log::log "Creating $1 network"
    docker network create "$1"
    log::log "Created $1 network"
  fi
}
