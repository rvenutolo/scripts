#!/usr/bin/env bash

# $1 = ip
function ipv4_to_num() {
  check_exactly_1_arg "$@"
  IFS=. read -r a b c d <<< "$1"
  echo "$(((a << 24) + (b << 16) + (c << 8) + d))"
}

# $1 = ip
function num_to_ipv4() {
  check_exactly_1_arg "$@"
  echo "$(($1 >> 24 & 0xff)).$(($1 >> 16 & 0xff)).$(($1 >> 8 & 0xff)).$(($1 & 0xff))"
}
