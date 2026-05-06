#!/usr/bin/env bash

# $1 = length (optional)
function passwords::generate() {
  args::check_at_most_1_arg "$@"
  pwgen --secure --capitalize --numerals --num-passwords 1 "${1:-64}"
}

# $1 = length (optional)
function passwords::generate_with_symbols() {
  args::check_at_most_1_arg "$@"
  pwgen --secure --capitalize --numerals --symbols \
    --remove-chars '!&*{}[],#>|@`"%-.$\\/:;='\' \
    --num-passwords 1 "${1:-64}"
}
