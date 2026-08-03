#!/usr/bin/env bash

# Per-test CLI invocation shim utility. Builds on path_shim.bash to drop fake
# executables that record their invocations to ${BATS_TEST_TMPDIR}/<name>.calls
# (one line per invocation, space-joined args), optionally with canned stdout
# output and exit codes. Also provides a passthrough sudo shim that strips
# `sudo` + leading flags and execs the rest.
#
# BATS isolates each @test in its own subshell, so PATH mutations, shim files,
# and counter files do not leak between tests.

# Drop bare invocation recorder. Shim writes "$*" to <name>.calls (one line per
# invocation), exits 0.
# $1 = command name
function cli_shim::record() {
  local -r name="$1"
  path_shim::mkbin
  cat > "${BATS_TEST_TMPDIR}/bin/${name}" << EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${BATS_TEST_TMPDIR}/${name}.calls"
exit 0
EOF
  chmod +x "${BATS_TEST_TMPDIR}/bin/${name}"
}

# Recorder + canned stdout + optional exit code (default 0).
# $1 = command name
# $2 = stdout content (may be multi-line; written verbatim with trailing newline)
# $3 = exit code (optional, default 0)
function cli_shim::record_with_output() {
  local -r name="$1"
  local -r stdout="$2"
  local -r exit_code="${3:-0}"
  path_shim::mkbin
  local -r out_file="${BATS_TEST_TMPDIR}/${name}.stdout"
  printf '%s\n' "${stdout}" > "${out_file}"
  cat > "${BATS_TEST_TMPDIR}/bin/${name}" << EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${BATS_TEST_TMPDIR}/${name}.calls"
cat "${out_file}"
exit ${exit_code}
EOF
  chmod +x "${BATS_TEST_TMPDIR}/bin/${name}"
}

# Stateful: returns Nth output on Nth call. Counter file ${name}.callno.
# Once outputs exhausted, repeats the last output indefinitely.
# $1 = command name
# $@ rest = outputs in order (each may be multi-line; written verbatim)
function cli_shim::record_stateful() {
  local -r name="$1"
  shift
  path_shim::mkbin
  local -r outputs_dir="${BATS_TEST_TMPDIR}/${name}.outputs"
  mkdir --parents "${outputs_dir}"
  local i=1
  for out in "$@"; do
    printf '%s\n' "${out}" > "${outputs_dir}/${i}"
    ((i += 1))
  done
  local -r last_index=$((i - 1))
  cat > "${BATS_TEST_TMPDIR}/bin/${name}" << EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${BATS_TEST_TMPDIR}/${name}.calls"
counter_file="${BATS_TEST_TMPDIR}/${name}.callno"
n=\$(cat "\${counter_file}" 2>/dev/null || printf '0')
n=\$(( n + 1 ))
printf '%s' "\${n}" > "\${counter_file}"
if (( n > ${last_index} )); then
  n=${last_index}
fi
cat "${outputs_dir}/\${n}"
exit 0
EOF
  chmod +x "${BATS_TEST_TMPDIR}/bin/${name}"
}

# Install sudo passthrough — strips `sudo` + leading flags, execs rest.
# Handles: sudo cmd, sudo -- cmd, sudo -E cmd, sudo -u USER cmd, sudo -n cmd.
# Long flags (--preserve-env, etc.) NOT handled; tests should use short forms.
function cli_shim::install_passthrough_sudo() {
  path_shim::mkbin
  cat > "${BATS_TEST_TMPDIR}/bin/sudo" << 'EOF'
#!/usr/bin/env bash
while [[ $# -gt 0 ]]; do
  case "$1" in
    --) shift; break ;;
    -E|-H|-n|-S|-k|-K|-A|-b|-i|-s|-V|-v|-l|-L) shift ;;
    -u|-g|-U|-h|-p|-C|-r|-t) shift 2 ;;
    -*) shift ;;
    *) break ;;
  esac
done
exec "$@"
EOF
  chmod +x "${BATS_TEST_TMPDIR}/bin/sudo"
}

# Read back recorded calls. One line per invocation, space-joined args.
# $1 = command name
# Output: stdout — call log contents (or empty if shim was never invoked)
function cli_shim::calls() {
  local -r name="$1"
  cat "${BATS_TEST_TMPDIR}/${name}.calls" 2> /dev/null || true
}

# Count recorded calls.
# $1 = command name
# Output: stdout — invocation count (0 if shim was never invoked)
function cli_shim::call_count() {
  local -r name="$1"
  if [[ -f "${BATS_TEST_TMPDIR}/${name}.calls" ]]; then
    wc --lines < "${BATS_TEST_TMPDIR}/${name}.calls"
  else
    printf '0\n'
  fi
}
