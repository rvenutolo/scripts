#!/usr/bin/env bash

# Convert a dotted-decimal IPv4 address to its 32-bit integer representation.
# $1 = IPv4 address (e.g. "192.168.1.1")
# Output: stdout — integer representation of the address
function ip::ipv4_to_num() {
  args::check_exactly_1_arg "$@"
  local a b c d
  IFS=. read -r a b c d <<< "$1"
  readonly a b c d
  printf '%s\n' "$(((a << 24) + (b << 16) + (c << 8) + d))"
}

# Convert a 32-bit integer to a dotted-decimal IPv4 address.
# $1 = integer representation of an IPv4 address
# Output: stdout — dotted-decimal address (e.g. "192.168.1.1")
function ip::num_to_ipv4() {
  args::check_exactly_1_arg "$@"
  printf '%s\n' "$(($1 >> 24 & 0xff)).$(($1 >> 16 & 0xff)).$(($1 >> 8 & 0xff)).$(($1 & 0xff))"
}
