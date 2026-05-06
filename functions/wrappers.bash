#!/usr/bin/env bash

# wrapper around curl to disable reading the config that is intended for interactive use
function wrappers::curl() {
  curl --disable --fail --silent --location --show-error "$@"
}

# wrapper around wget to disable reading the config that is intended for interactive use
function wrappers::wget() {
  wget --no-config "$@"
}
