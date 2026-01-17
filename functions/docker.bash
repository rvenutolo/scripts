#!/usr/bin/env bash

# $1 = container name
function container_is_running() {
  check_exactly_1_arg "$@"
  [[ -n "$(docker ps --quiet --filter "name=^$1\$")" ]] && [[ "$(docker container inspect -f '{{.State.Status}}' "$1")" == 'running' ]]
}

# $1 = container name
function wait_for_healthy_container() {
  log "Waiting for $1 to be healthy"
  until [[ "$(docker inspect -f '{{.State.Health.Status}}' $1)" == 'healthy' ]]; do
    sleep 0.1
  done
}

# $1 = docker network name
function create_docker_network() {
  check_exactly_1_arg "$@"
  if ! docker network inspect "$1" &> '/dev/null'; then
    log "Creating $1 network"
    docker network create "$1"
    log "Created $1 network"
  fi
}
