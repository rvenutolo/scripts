#!/usr/bin/env bash

# $1 = container name
function container_is_running() {
  check_exactly_1_arg "$@"
  [[ -n "$(docker ps --quiet --filter "name=^$1\$")" ]] && [[ "$(docker container inspect -f '{{.State.Status}}' "$1")" == 'running' ]]
}
