#!/usr/bin/env bash

# @description Run curl with flags suitable for non-interactive use: disables ~/.curlrc, fails on HTTP errors.
# @arg $@ additional curl arguments and URL
function http::curl() {
  # pass-through: any arg count valid (forwarded to curl)
  curl --disable --fail --silent --location --show-error "$@"
}

# @description Run wget with flags suitable for non-interactive use: disables ~/.wgetrc.
# @arg $@ additional wget arguments and URL
function http::wget() {
  # pass-through: any arg count valid (forwarded to wget)
  wget --no-config "$@"
}

# @description Predicate: is the URL reachable? Uses a HEAD request (no body download).
# @arg $1 URL
# @exitcode 0 if reachable
# @exitcode 1 otherwise
function http::url_reachable() {
  args::check_exactly_1_arg "$@"
  local -r url="$1"
  http::curl --output '/dev/null' --head "${url}"
}
