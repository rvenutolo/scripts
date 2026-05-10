#!/usr/bin/env bash

# Shared test setup loader for all *.bats files under test/functions/.
# Each .bats file's setup() loads this, then sources the file under test.
#
# Globals exported:
#   SCRIPTS_DIR  — repo root, resolved from BATS_TEST_DIRNAME
#
# bats-support / bats-assert are loaded here so individual test files do not
# repeat the relative-path dance.

# BATS_TEST_DIRNAME points at test/functions (the dir of the running .bats file).
# Repo root is two levels up.
SCRIPTS_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
export SCRIPTS_DIR

load "${SCRIPTS_DIR}/test/test_helper/bats-support/load"
load "${SCRIPTS_DIR}/test/test_helper/bats-assert/load"

# log.bash is sourced eagerly because args::check_* helpers call log::die on failure.
# shellcheck disable=SC1091 # path resolved at runtime via SCRIPTS_DIR
source "${SCRIPTS_DIR}/functions/log.bash"
