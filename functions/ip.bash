#!/usr/bin/env bash

# $1 = ip
function ip::ipv4_to_num() {
  args::check_exactly_1_arg "$@"
  local a b c d
  IFS=. read -r a b c d <<< "$1"
  readonly a b c d
  printf '%s\n' "$(((a << 24) + (b << 16) + (c << 8) + d))"
}

# $1 = ip
function ip::num_to_ipv4() {
  args::check_exactly_1_arg "$@"
  printf '%s\n' "$(($1 >> 24 & 0xff)).$(($1 >> 16 & 0xff)).$(($1 >> 8 & 0xff)).$(($1 & 0xff))"
}
