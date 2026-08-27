bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  SHIM_DIR="${REPO_DIR}/scripts/shims/claude"
  # Every case runs against an exact PATH of shim dir + stub dir, so the real
  # killall can never be reached: if the shim has a bug, the payload that runs
  # is the stub's PAYLOAD_RAN line, not a live kill.
  STUB_DIR="${BATS_TEST_TMPDIR}/stub"
  mkdir --parents "${STUB_DIR}"
  make_stub pkill
  make_stub killall
  # The shims' `#!/usr/bin/env bash` resolves bash through the restricted PATH,
  # so the stub dir must carry the devShell's bash too.
  ln --symbolic "$(type -P bash)" "${STUB_DIR}/bash"
}

# Write a fake <name> into STUB_DIR that records its argv and exits 0.
make_stub() {
  local -r name="$1"
  cat > "${STUB_DIR}/${name}" << 'EOF'
#!/usr/bin/env bash
printf 'PAYLOAD_RAN %s\n' "$*"
EOF
  chmod +x "${STUB_DIR}/${name}"
}

# Run the killall shim with an exact PATH. BASH_ENV=SAFE_BASH_ENV: an ambient
# ~/.bashrc would re-prepend the nix PATH ahead of the stub dir and an allowed
# case would exec the REAL killall. `timeout` bounds the one failure mode that
# would otherwise hang forever — a shim that fails to exclude its own dir
# exec's itself in a loop.
run_shim() {
  run timeout 10 env PATH="${SHIM_DIR}:${STUB_DIR}" \
    BASH_ENV="${SAFE_BASH_ENV}" "${SHIM_DIR}/killall" "$@"
}

# Like run_shim, but with an explicit PATH ($1) and shim path ($2).
run_shim_with() {
  local -r path="$1"
  local -r shim="$2"
  shift 2
  run timeout 10 env PATH="${path}" \
    BASH_ENV="${SAFE_BASH_ENV}" "${shim}" "$@"
}

assert_refused() {
  assert_failure 125
  assert_output --partial 'killall: refused:'
  # shellcheck disable=SC2016 # single quotes intentional: asserting the literal ${pid} text in the shim's message
  assert_output --partial 'kill "${pid}"'
  refute_output --partial 'PAYLOAD_RAN'
}

@test "killall x is refused" {
  run_shim x
  assert_refused
  assert_output --partial 'shorter than 4 characters'
}

@test "killall firefox-bin passes through verbatim" {
  run_shim firefox-bin
  assert_success
  assert_output 'PAYLOAD_RAN firefox-bin'
}

@test "killall x firefox-bin is refused (every name is checked)" {
  run_shim x firefox-bin
  assert_refused
}

@test "killall firefox-bin x is refused (every name is checked)" {
  run_shim firefox-bin x
  assert_refused
}

@test "killall firefox-bin plasmashell is refused" {
  run_shim firefox-bin plasmashell
  assert_refused
  assert_output --partial "'plasmashell'"
}

@test "killall -u me (no name) is refused" {
  run_shim -u me
  assert_refused
  assert_output --partial 'no process name given'
}

@test "killall with no arguments is refused" {
  run_shim
  assert_refused
}

@test "killall -s TERM firefox-bin: separated value skipped" {
  run_shim -s TERM firefox-bin
  assert_success
  assert_output 'PAYLOAD_RAN -s TERM firefox-bin'
}

@test "killall -TERM firefox-bin: signal name takes no value" {
  run_shim -TERM firefox-bin
  assert_success
  assert_output 'PAYLOAD_RAN -TERM firefox-bin'
}

@test "killall --user=me firefox-bin: attached long value skipped" {
  run_shim --user=me firefox-bin
  assert_success
  assert_output 'PAYLOAD_RAN --user=me firefox-bin'
}

@test "killall --older-than 5m firefox-bin: separated long value skipped" {
  run_shim --older-than 5m firefox-bin
  assert_success
  assert_output 'PAYLOAD_RAN --older-than 5m firefox-bin'
}

@test "killall -Z ctx firefox-bin: single uppercase value option skips its value" {
  run_shim -Z ctx firefox-bin
  assert_success
  assert_output 'PAYLOAD_RAN -Z ctx firefox-bin'
}

@test "killall -e -w firefox-bin: flags take no value" {
  run_shim -e -w firefox-bin
  assert_success
  assert_output 'PAYLOAD_RAN -e -w firefox-bin'
}

@test "killall -- -odd-name: name after -- is allowed" {
  run_shim -- -odd-name
  assert_success
  assert_output 'PAYLOAD_RAN -- -odd-name'
}

@test "killall --help is not intercepted" {
  run_shim --help
  assert_success
  assert_output 'PAYLOAD_RAN --help'
}

@test "killall -s -h kwin: -h as an option value does not pass through" {
  run_shim -s -h kwin
  assert_refused
  assert_output --partial "session-critical process 'kwin'"
}

@test "exits 127 when no real killall exists on PATH" {
  local bash_only="${BATS_TEST_TMPDIR}/bash-only"
  mkdir --parents "${bash_only}"
  ln --symbolic "$(type -P bash)" "${bash_only}/bash"
  run -127 timeout 10 env PATH="${SHIM_DIR}:${bash_only}" \
    BASH_ENV="${SAFE_BASH_ENV}" "${SHIM_DIR}/killall" firefox-bin
  assert_failure 127
  assert_output --partial 'killall: real binary not found on PATH'
}
