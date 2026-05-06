#!/usr/bin/env bash

#shellcheck disable=SC2120
function network::local_ip() {
  args::check_no_args "$@"
  ip -oneline route get to '8.8.8.8' | sed --quiet 's/.*src \([0-9.]\+\).*/\1/p'
}

function network::local_network() {
  args::check_no_args "$@"
  local ip_num
  ip_num="$(ip::ipv4_to_num "$(network::local_ip)" || exit 1)" || exit 1
  readonly ip_num
  if [[ $(ip::ipv4_to_num '10.0.0.0') -le "${ip_num}" && "${ip_num}" -le $(ip::ipv4_to_num '10.255.255.255') ]]; then
    printf '%s\n' '10.0.0.0/8'
  elif [[ $(ip::ipv4_to_num '172.16.0.0') -le "${ip_num}" && "${ip_num}" -le $(ip::ipv4_to_num '172.31.255.255') ]]; then
    printf '%s\n' '172.16.0.0/12'
  elif [[ $(ip::ipv4_to_num '192.168.0.0') -le "${ip_num}" && "${ip_num}" -le $(ip::ipv4_to_num '192.168.255.255') ]]; then
    printf '%s\n' '192.168.0.0/16'
  else
    log::die "Could not determine local network IPv4 range"
  fi
}
