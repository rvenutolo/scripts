#!/usr/bin/env bash

# Per-test fixture for /etc/os-release contents. Writes a fixture file under
# ${BATS_TEST_TMPDIR}/os-release and installs a shell function override of the
# `source` builtin that redirects calls to '/etc/os-release' at the fixture.
#
# BATS isolates each @test in its own subshell, so the override and fixture
# do not leak between tests.

# Writes ${BATS_TEST_TMPDIR}/os-release with the given KEY=VALUE lines.
# $@ = lines verbatim (e.g. "ID=ubuntu" 'VERSION_CODENAME="jammy"')
# Output: stdout — fixture path
function os_release_fixture::create() {
  local -r fixture="${BATS_TEST_TMPDIR}/os-release"
  : >"${fixture}"
  for line in "$@"; do
    printf '%s\n' "${line}" >>"${fixture}"
  done
  printf '%s\n' "${fixture}"
}

# Installs a `source` function that intercepts '/etc/os-release' calls and
# redirects to the fixture path. All other source calls pass through to the
# `source` builtin unchanged. Exported so it propagates to bash -c subshells
# (bash subshell `(...)` blocks already inherit it).
function os_release_fixture::install_source_override() {
  # shellcheck disable=SC2329 # invoked indirectly by bash function lookup when os::release_field calls `source`
  source() {
    if [[ $1 == '/etc/os-release' ]]; then
      builtin source "${BATS_TEST_TMPDIR}/os-release"
    else
      builtin source "$@"
    fi
  }
  export -f source
}
