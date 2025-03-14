#!/usr/bin/env bash

# wrapper around curl to disable reading the config that is intended for interactive use
function curl_wrapper() {
  curl --disable --fail --silent --location --show-error "$@"
}

# wrapper around wget to disable reading the config that is intended for interactive use
function wget_wrapper() {
  wget --no-config "$@"
}
