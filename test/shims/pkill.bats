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

# ---------- refusals ----------

@test "pkill -f kwin_x11 is refused" {
  run_shim -f kwin_x11
  assert_refused
  assert_output --partial "session-critical process 'kwin'"
}

@test "pkill --full startplasma is refused" {
  run_shim --full startplasma
  assert_refused
}

@test "pkill -TERM -f xorg is refused (signal name is not a value)" {
  run_shim -TERM -f xorg
  assert_refused
  assert_output --partial "'xorg'"
}

@test "pkill -f 'Xorg' is refused case-insensitively" {
  run_shim -f Xorg
  assert_refused
}

@test "pkill -u rvenutolo (no pattern) is refused" {
  run_shim -u rvenutolo
  assert_refused
  assert_output --partial 'no pattern given'
}

@test "pkill with no arguments is refused" {
  run_shim
  assert_refused
  assert_output --partial 'no pattern given'
}

@test "pkill .*x is refused as too short" {
  run_shim '.*x'
  assert_refused
  assert_output --partial 'shorter than 4 characters'
}

@test "pkill kw is refused as too short" {
  run_shim kw
  assert_refused
}

@test "refusal names the pattern and both fixes" {
  run_shim --full x
  assert_refused
  assert_output --partial "pattern: 'x'"
  assert_output --partial 'more specific pattern'
}

# ---------- option values are skipped in every shape ----------

@test "pkill -s 9 -u rvenutolo some-daemon: separated values skipped" {
  run_shim -s 9 -u rvenutolo some-daemon
  assert_success
  assert_output 'PAYLOAD_RAN -s 9 -u rvenutolo some-daemon'
}

@test "pkill --signal=9 some-daemon: attached long value skipped" {
  run_shim --signal=9 some-daemon
  assert_success
  assert_output 'PAYLOAD_RAN --signal=9 some-daemon'
}

@test "pkill --signal 9 some-daemon: separated long value skipped" {
  run_shim --signal 9 some-daemon
  assert_success
  assert_output 'PAYLOAD_RAN --signal 9 some-daemon'
}

@test "pkill -s9 some-daemon: attached short value skipped" {
  run_shim -s9 some-daemon
  assert_success
  assert_output 'PAYLOAD_RAN -s9 some-daemon'
}

@test "pkill -fs 9 some-daemon: cluster whose last letter takes a value" {
  run_shim -fs 9 some-daemon
  assert_success
  assert_output 'PAYLOAD_RAN -fs 9 some-daemon'
}

@test "pkill -9 some-daemon: numeric signal takes no value" {
  run_shim -9 some-daemon
  assert_success
  assert_output 'PAYLOAD_RAN -9 some-daemon'
}

@test "pkill -STOP some-daemon: uppercase signal takes no value" {
  run_shim -STOP some-daemon
  assert_success
  assert_output 'PAYLOAD_RAN -STOP some-daemon'
}

@test "pkill -P 1234 some-daemon: single uppercase value option skips its value" {
  run_shim -P 1234 some-daemon
  assert_success
  assert_output 'PAYLOAD_RAN -P 1234 some-daemon'
}

@test "pkill -s 9 alone (value consumed, no pattern) is refused" {
  run_shim -s 9
  assert_refused
  assert_output --partial 'no pattern given'
}

@test "pkill -- -leading-dash-name: pattern after -- is allowed" {
  run_shim -- -leading-dash-name
  assert_success
  assert_output 'PAYLOAD_RAN -- -leading-dash-name'
}

@test "pkill -- x: pattern after -- is still checked" {
  run_shim -- x
  assert_refused
}

# ---------- pass-through ----------

@test "pkill --help is not intercepted" {
  run_shim --help
  assert_success
  assert_output 'PAYLOAD_RAN --help'
}

@test "pkill -V is not intercepted" {
  run_shim -V
  assert_success
  assert_output 'PAYLOAD_RAN -V'
}

# ---------- real-binary resolution ----------

@test "shim dir reached through a symlink still excludes itself" {
  ln --symbolic "${SHIM_DIR}" "${BATS_TEST_TMPDIR}/link"
  run_shim_with "${BATS_TEST_TMPDIR}/link:${STUB_DIR}" "${BATS_TEST_TMPDIR}/link/pkill" --full my-specific-daemon
  assert_success
  assert_output 'PAYLOAD_RAN --full my-specific-daemon'
}

@test "shim dir given as a relative PATH entry still excludes itself" {
  mkdir --parents "${BATS_TEST_TMPDIR}/rel"
  cp --recursive "${SHIM_DIR}" "${BATS_TEST_TMPDIR}/rel/shims"
  cd "${BATS_TEST_TMPDIR}" || return 1
  run_shim_with "rel/shims:${STUB_DIR}" 'rel/shims/pkill' --full my-specific-daemon
  assert_success
  assert_output 'PAYLOAD_RAN --full my-specific-daemon'
}

@test "an empty PATH entry never selects a pkill in the cwd" {
  cd "${BATS_TEST_TMPDIR}" || return 1
  printf '#!/usr/bin/env bash\nprintf CWD_RAN\n' > "${BATS_TEST_TMPDIR}/pkill"
  chmod +x "${BATS_TEST_TMPDIR}/pkill"
  run_shim_with "${SHIM_DIR}::${STUB_DIR}" "${SHIM_DIR}/pkill" --full my-specific-daemon
  assert_success
  assert_output 'PAYLOAD_RAN --full my-specific-daemon'
  refute_output --partial 'CWD_RAN'
}

@test "exits 127 when no real pkill exists on PATH" {
  local bash_only="${BATS_TEST_TMPDIR}/bash-only"
  mkdir --parents "${bash_only}"
  ln --symbolic "$(type -P bash)" "${bash_only}/bash"
  run_shim_with "${SHIM_DIR}:${bash_only}" "${SHIM_DIR}/pkill" --full my-specific-daemon
  assert_failure 127
  assert_output --partial 'pkill: real binary not found on PATH'
  refute_output --partial 'PAYLOAD_RAN'
}

@test "refusal happens before resolution: no real pkill and a bad pattern still exits 125" {
  local bash_only="${BATS_TEST_TMPDIR}/bash-only"
  mkdir --parents "${bash_only}"
  ln --symbolic "$(type -P bash)" "${bash_only}/bash"
  run_shim_with "${SHIM_DIR}:${bash_only}" "${SHIM_DIR}/pkill" --full x
  assert_failure 125
}
