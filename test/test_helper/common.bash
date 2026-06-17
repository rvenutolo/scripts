#!/usr/bin/env bash

# Shared test setup loader for all *.bats files under test/functions/.
# Each .bats file's setup() loads this, then sources the file under test.
#
# Globals exported:
#   REPO_DIR     — repo root, resolved from BATS_TEST_DIRNAME
#   SCRIPTS_DIR  — = repo-root/scripts, the function library
#
# bats-support / bats-assert are loaded here so individual test files do not
# repeat the relative-path dance.

# BATS_TEST_DIRNAME points at test/functions (the dir of the running .bats file).
# Repo root is two levels up; the function library lives under scripts/.
REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
SCRIPTS_DIR="${REPO_DIR}/scripts"
export REPO_DIR SCRIPTS_DIR

load "${REPO_DIR}/test/test_helper/bats-support/load"
load "${REPO_DIR}/test/test_helper/bats-assert/load"

# log.bash is sourced eagerly because args::check_* helpers call log::die on failure.
# shellcheck disable=SC1091 # path resolved at runtime via SCRIPTS_DIR
source "${SCRIPTS_DIR}/functions/log.bash"
