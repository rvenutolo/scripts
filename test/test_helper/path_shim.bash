#!/usr/bin/env bash

# Per-test PATH shim utility. Creates ${BATS_TEST_TMPDIR}/bin, prepends to PATH,
# and lets tests drop fake executables in for hostname stubs, fake binaries,
# wrapper-vs-real differentiation, etc.
#
# BATS isolates each @test in its own subshell, so PATH mutations and shim files
# do not leak between tests.

# Creates ${BATS_TEST_TMPDIR}/bin if missing, prepends to PATH (idempotent).
function path_shim::mkbin() {
  local -r bindir="${BATS_TEST_TMPDIR}/bin"
  mkdir --parents "${bindir}"
  case ":${PATH}:" in
  *":${bindir}:"*) ;;
  *) PATH="${bindir}:${PATH}" ;;
  esac
}

# Writes an executable shim ${BATS_TEST_TMPDIR}/bin/<name> with the given body.
# $1 = command name
# $2 = full script body (must include shebang)
function path_shim::add() {
  local -r name="$1"
  local -r body="$2"
  path_shim::mkbin
  printf '%s\n' "${body}" >"${BATS_TEST_TMPDIR}/bin/${name}"
  chmod +x "${BATS_TEST_TMPDIR}/bin/${name}"
}
