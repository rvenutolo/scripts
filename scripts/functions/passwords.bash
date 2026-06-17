#!/usr/bin/env bash

# @description Generate a secure random password using pwgen (alphanumeric only).
# Output: stdout — generated password
# @arg $1 password length (optional; defaults to 64)
function passwords::generate() {
  args::check_at_most_1_arg "$@"
  pwgen --secure --capitalize --numerals --num-passwords 1 "${1:-64}"
}

# @description Generate a secure random password using pwgen, including symbols (unsafe chars excluded).
# Output: stdout — generated password
# @arg $1 password length (optional; defaults to 64)
function passwords::generate_with_symbols() {
  args::check_at_most_1_arg "$@"
  pwgen --secure --capitalize --numerals --symbols \
    --remove-chars '!&*{}[],#>|@`"%-.$\\/:;='\' \
    --num-passwords 1 "${1:-64}"
}
