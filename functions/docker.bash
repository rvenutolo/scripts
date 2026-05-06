#!/usr/bin/env bash

# Return true if the named Docker container exists and its status is 'running'.
# $1 = container name
function docker::container_is_running() {
  args::check_exactly_1_arg "$@"
  strings::is_not_empty "$(docker ps --quiet --filter "name=^$1\$")" \
    && [[ "$(docker container inspect --format '{{.State.Status}}' "$1")" == 'running' ]]
}

# Block until the named Docker container reports a health status of 'healthy'.
# $1 = container name
function docker::wait_for_healthy_container() {
  log::log "Waiting for $1 to be healthy"
  until [[ "$(docker inspect --format '{{.State.Health.Status}}' "$1")" == 'healthy' ]]; do
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
