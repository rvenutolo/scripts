#!/usr/bin/env bash

# Run curl with flags suitable for non-interactive use: disables ~/.curlrc, fails on HTTP errors.
# $@ = additional curl arguments and URL
function wrappers::curl() {
  # pass-through: any arg count valid (forwarded to curl)
  curl --disable --fail --silent --location --show-error "$@"
}

# Run wget with flags suitable for non-interactive use: disables ~/.wgetrc.
# $@ = additional wget arguments and URL
function wrappers::wget() {
  # pass-through: any arg count valid (forwarded to wget)
  wget --no-config "$@"
}
