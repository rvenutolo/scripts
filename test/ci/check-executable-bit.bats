setup() {
  load '../test_helper/common'
  # Capture the real check path BEFORE any cd into the fixture repo — REPO_DIR
  # from common.bash points at the real repo here, and the tests cd away.
  CHECK="${REPO_DIR}/.ci/check-executable-bit"
  REAL_REPO_DIR="${REPO_DIR}"
  REPO="${BATS_TEST_TMPDIR}/repo"

  # The check resolves its own repo root via `git rev-parse --show-toplevel`
  # from the CWD and scans it with shell_scripts::find, so a bare `git init`
  # tmpdir is all the isolation needed. SCRIPTS_DIR keeps pointing at the real
  # library: the check sources it, but classifies purely on paths relative to
  # the repo root, so nothing has to be staged into the fixture.
  mkdir --parents "${REPO}"/scripts/{non-interactive,interactive,misc,functions,install,set_up,other}
  mkdir --parents "${REPO}"/scripts/set_up/{docker,sysctl,tailscale}
  mkdir --parents "${REPO}/.ci" "${REPO}/.githooks" "${REPO}/test/ci" "${REPO}/lib"
  git init --quiet "${REPO}"

  # One compliant file in every enforced location, so the default tree passes
  # and each failure test introduces exactly one violation of its own.
  make_script 'scripts/non-interactive/good' exec
  make_script 'scripts/interactive/good' exec
  make_script 'scripts/misc/good' exec
  make_script '.ci/check-good' exec
  make_script '.githooks/good-hook' exec
  make_script 'run-tests' exec
  make_script 'scripts/other/vendored' exec
  make_script 'scripts/functions/topic.bash'
  make_bats 'test/ci/thing.bats'

  # The GATED entries in .ci/check-executable-bit must each exist and be
  # non-executable, or its drift pass fails on the default tree. These mirror
  # the real array; change both together. Same approach as
  # test/ci/check-script-has-test.bats, which creates a fixture script at the
  # real exempt name apply-repo-settings.
  make_script 'scripts/set_up/docker/enable-rootless-docker'
  make_script 'scripts/set_up/sysctl/copy-sysctl-rootless-docker-file'
  make_script 'scripts/set_up/tailscale/set-tailscale-netfilter-mode'
}

# Apply the requested mode to a fixture file: `exec` makes it executable,
# anything else (including empty) makes it non-executable.
set_fixture_mode() {
  local -r path="$1"
  local -r mode="$2"
  if [[ "${mode}" == 'exec' ]]; then
    chmod +x "${REPO}/${path}"
  else
    chmod -x "${REPO}/${path}"
  fi
}

# Write a shebang-bearing file at ${REPO}/<path>. Pass `exec` as $2 to make it
# executable; omit $2 for a non-executable one.
make_script() {
  printf '#!/usr/bin/env bash\ntrue\n' > "${REPO}/$1"
  set_fixture_mode "$1" "${2:-}"
}

# Write a .bats file (no shebang — bats files start with a function) at
# ${REPO}/<path>. Pass `exec` as $2 to make it executable.
make_bats() {
  printf '@test "x" { true; }\n' > "${REPO}/$1"
  set_fixture_mode "$1" "${2:-}"
}

# Run the check against the fixture repo. Must cd first so the check's
# `git rev-parse --show-toplevel` resolves to the fixture.
run_check() {
  cd "${REPO}"
  run "${CHECK}" "$@"
}

@test "passes on a clean fixture tree" {
  run_check
  assert_success
}

@test "fails when a script under scripts/non-interactive/ is not executable" {
  make_script 'scripts/non-interactive/bad'
  run_check
  assert_failure
  assert_output --partial 'scripts/non-interactive/bad'
  assert_output --partial 'must be executable'
}

@test "fails when a script under scripts/interactive/ is not executable" {
  make_script 'scripts/interactive/bad'
  run_check
  assert_failure
  assert_output --partial 'scripts/interactive/bad'
  assert_output --partial 'must be executable'
}

@test "fails when a script under scripts/misc/ is not executable" {
  make_script 'scripts/misc/bad'
  run_check
  assert_failure
  assert_output --partial 'scripts/misc/bad'
  assert_output --partial 'must be executable'
}

@test "fails when a script under .ci/ is not executable" {
  make_script '.ci/check-bad'
  run_check
  assert_failure
  assert_output --partial '.ci/check-bad'
  assert_output --partial 'must be executable'
}

@test "fails when a hook under .githooks/ is not executable" {
  make_script '.githooks/bad-hook'
  run_check
  assert_failure
  assert_output --partial '.githooks/bad-hook'
  assert_output --partial 'must be executable'
}

@test "fails when a repo-root runner is not executable" {
  make_script 'run-set-up-scripts'
  run_check
  assert_failure
  assert_output --partial 'run-set-up-scripts'
  assert_output --partial 'must be executable'
}

@test "fails when a functions library file is executable" {
  make_script 'scripts/functions/oops.bash' exec
  run_check
  assert_failure
  assert_output --partial 'scripts/functions/oops.bash'
  assert_output --partial 'must not be executable'
}

@test "passes when a functions library file is not executable" {
  make_script 'scripts/functions/fine.bash'
  run_check
  assert_success
}

@test "fails when a bats file is executable" {
  make_bats 'test/ci/oops.bats' exec
  run_check
  assert_failure
  assert_output --partial 'test/ci/oops.bats'
  assert_output --partial 'must not be executable'
}

@test "fails when a non-executable, non-gated script sits under scripts/install/" {
  # Renamed from the old 00_MARKER fixture: make_script writes a shebang, so
  # unlike the real all-caps marker files this one DOES reach the classifier,
  # and the old name asserted the opposite of what the fixture is.
  make_script 'scripts/install/50_thing'
  run_check
  assert_failure
  assert_output --partial 'scripts/install/50_thing'
  assert_output --partial 'must be executable'
}

@test "fails when a non-executable, non-gated script sits under scripts/set_up/" {
  make_script 'scripts/set_up/disabled-thing'
  run_check
  assert_failure
  assert_output --partial 'scripts/set_up/disabled-thing'
  assert_output --partial 'must be executable'
}

@test "rule order: the library rule precedes the install/set_up rule" {
  # *.bash | *.bats is now matched BEFORE the install/set_up arm, so a library
  # file there is still must-not-be-executable. Swapping the two arms back would
  # make the install/set_up arm demand the exec bit on a library file instead.
  make_script 'scripts/install/helper.bash' exec
  run_check
  assert_failure
  assert_output --partial 'scripts/install/helper.bash'
  assert_output --partial 'must not be executable'
}

@test "an executable script under scripts/set_up/ passes" {
  # set_up/ scripts must be executable unless listed in GATED. This one is not
  # gated, so the exec bit is exactly what the rule requires.
  make_script 'scripts/set_up/enabled-thing' exec
  run_check
  assert_success
}

@test "passes when a gated script under scripts/set_up/ is not executable" {
  # The three GATED entries are created non-executable in setup(); assert it
  # explicitly rather than leaning on the clean-tree test.
  run_check
  assert_success
}

@test "passes when a script under scripts/install/ is executable" {
  make_script 'scripts/install/60_thing' exec
  run_check
  assert_success
}

@test "passes when a non-executable .bash sits under scripts/install/" {
  # The flipped-order companion to the rule-order test above.
  make_script 'scripts/install/helper.bash'
  run_check
  assert_success
}

@test "passes on a shell-extension file with no shebang" {
  # shfmt --find matches by extension as well as by shebang, so this file DOES
  # reach rule 3 — only assert_executable's shebang gate lets it through.
  # Deleting that gate makes this test fail, which is the point.
  printf 'echo hi\n' > "${REPO}/scripts/non-interactive/notes.sh"
  chmod -x "${REPO}/scripts/non-interactive/notes.sh"
  run_check
  assert_success
}

@test "ignores a shebang script in an unenforced subdirectory" {
  make_script 'lib/helper'
  run_check
  assert_success
}

@test "reports every violation in a single run" {
  make_script 'scripts/non-interactive/bad-one'
  make_script 'scripts/functions/bad-two.bash' exec
  run_check
  assert_failure
  assert_output --partial 'scripts/non-interactive/bad-one'
  assert_output --partial 'scripts/functions/bad-two.bash'
}

@test "fails when a script under scripts/other/ is not executable" {
  make_script 'scripts/other/stripped'
  run_check
  assert_failure
  assert_output --partial 'scripts/other/stripped'
  assert_output --partial 'must be executable'
}

@test "passes when a script under scripts/other/ is executable" {
  make_script 'scripts/other/vendored-two' exec
  run_check
  assert_success
}

@test "passes on a file under scripts/other/ with no shebang" {
  # scripts/other/README in the real tree. No shebang and no shell extension, so
  # shfmt --find never emits it and it does not reach the classifier at all;
  # assert_executable's shebang gate is the second line of defense.
  printf 'not a script\n' > "${REPO}/scripts/other/README"
  run_check
  assert_success
}

@test "reports every stale gated entry in a single run" {
  # Pins aggregation: an implementation that returned on the first stale entry
  # would pass the two single-violation tests but fail this one.
  chmod +x "${REPO}/scripts/set_up/docker/enable-rootless-docker"
  rm "${REPO}/scripts/set_up/tailscale/set-tailscale-netfilter-mode"
  run_check
  assert_failure
  assert_output --partial 'scripts/set_up/docker/enable-rootless-docker'
  assert_output --partial 'scripts/set_up/tailscale/set-tailscale-netfilter-mode'
}

@test "prints help and exits 0 for --help" {
  run_check --help
  assert_success
  assert_output --partial 'executable-bit convention'
}

@test "dies when given an unexpected argument" {
  run_check oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "fails when a gated entry has been re-enabled with chmod +x" {
  chmod +x "${REPO}/scripts/set_up/docker/enable-rootless-docker"
  run_check
  assert_failure
  assert_output --partial 'scripts/set_up/docker/enable-rootless-docker'
  assert_output --partial 'gated entry is executable'
}

@test "fails when a gated entry no longer exists on disk" {
  rm "${REPO}/scripts/set_up/tailscale/set-tailscale-netfilter-mode"
  run_check
  assert_failure
  assert_output --partial 'scripts/set_up/tailscale/set-tailscale-netfilter-mode'
  assert_output --partial 'gated entry does not exist'
}

@test "exits 0 against the real repo" {
  cd "${REAL_REPO_DIR}"
  run "${CHECK}"
  assert_success
}
