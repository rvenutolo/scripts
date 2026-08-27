setup() {
  load '../test_helper/common'
  SHIM_DIR="${REPO_DIR}/scripts/shims/claude"
  # Every case runs against an exact PATH of shim dir + stub dir, so the real
  # pkill can never be reached: if the shim has a bug, the payload that runs
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

# Run the pkill shim with an exact PATH. BASH_ENV=SAFE_BASH_ENV: an ambient
# ~/.bashrc would re-prepend the nix PATH ahead of the stub dir and an allowed
# case would exec the REAL pkill. `timeout` bounds the one failure mode that
# would otherwise hang forever — a shim that fails to exclude its own dir
# exec's itself in a loop.
run_shim() {
  run timeout 10 env PATH="${SHIM_DIR}:${STUB_DIR}" \
    BASH_ENV="${SAFE_BASH_ENV}" "${SHIM_DIR}/pkill" "$@"
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
  assert_output --partial 'pkill: refused:'
  # shellcheck disable=SC2016 # single quotes intentional: asserting the literal ${pid} text in the shim's message
  assert_output --partial 'kill "${pid}"'
  refute_output --partial 'PAYLOAD_RAN'
}

@test "pkill --full x is refused (the incident's shape)" {
  run_shim --full x
  assert_refused
  assert_output --partial 'shorter than 4 characters'
}

@test "pkill --full my-specific-daemon passes through verbatim" {
  run_shim --full my-specific-daemon
  assert_success
  assert_output 'PAYLOAD_RAN --full my-specific-daemon'
}

@test "pkill sddm is refused as session-critical" {
  run_shim sddm
  assert_refused
  assert_output --partial "session-critical process 'sddm'"
}
