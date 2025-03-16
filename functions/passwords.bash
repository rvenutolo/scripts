#!/usr/bin/env bash

# $1 = length
function generate_password() {
  check_at_most_1_arg "$@"
  pwgen --secure --capitalize --numerals --symbols --remove-chars '$\\/:;=`"'\' --num-passwords 1 "${1:-32}"
}
