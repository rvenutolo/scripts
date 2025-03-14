#!/usr/bin/env bash

# Copy to other scripts: source "${SCRIPTS_DIR}/functions.bash"

# shellcheck disable=SC1090
for file in "${SCRIPTS_DIR}"/functions/*.bash; do
  source "${file}"
done
