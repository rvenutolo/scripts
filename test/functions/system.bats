#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/strings.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/misc.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/prompt.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/system.bash"
}

# ---------- require_bash_version ----------

@test "require_bash_version: succeeds on 1 0 (host satisfies)" {
  run system::require_bash_version 1 0
  assert_success
}

@test "require_bash_version: succeeds on host major + minor 0" {
  run system::require_bash_version "${BASH_VERSINFO[0]}" 0
  assert_success
}

@test "require_bash_version: succeeds on host major.minor exactly" {
  run system::require_bash_version "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}"
  assert_success
}

@test "require_bash_version: dies on impossibly large major" {
  run system::require_bash_version 99 0
  assert_failure
  assert_output --partial 'bash 99.0+ required'
}

@test "require_bash_version: dies on host major + impossibly large minor" {
  run system::require_bash_version "${BASH_VERSINFO[0]}" 99
  assert_failure
  assert_output --partial "bash ${BASH_VERSINFO[0]}.99+ required"
}

@test "require_bash_version: dies with no args" {
  run system::require_bash_version
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "require_bash_version: dies with one arg" {
  run system::require_bash_version 4
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "require_bash_version: dies with three args" {
  run system::require_bash_version 4 0 0
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

# ---------- reload_sysctl_conf (Phase G) ----------

@test "reload_sysctl_conf: invokes sudo sysctl --system --quiet on confirm=y" {
  load '../test_helper/path_shim'
  # shellcheck disable=SC1091
  source "${REPO_DIR}/test/test_helper/cli_shim.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/misc.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/prompt.bash"
  cli_shim::install_passthrough_sudo
  cli_shim::record sysctl
  export SCRIPTS_AUTO_ANSWER=y
  run system::reload_sysctl_conf
  assert_success
  run cli_shim::calls sysctl
  assert_output '--system --quiet'
}

@test "reload_sysctl_conf: no-op when confirm=n" {
  # Feed 'n' via stdin so prompt::yn sees a real 'no' without hanging.
  # Run in a subprocess with the passthrough-sudo shim on PATH so sysctl is
  # never invoked; verify via the call-count file.
  local calls_file="${BATS_TEST_TMPDIR}/sysctl.calls"
  local bin_dir="${BATS_TEST_TMPDIR}/bin"
  mkdir --parents "${bin_dir}"
  # write a recording sysctl shim
  printf '#!/usr/bin/env bash\nprintf "%%s\n" "$*" >> "%s"\n' "${calls_file}" > "${bin_dir}/sysctl"
  chmod +x "${bin_dir}/sysctl"
  # passthrough sudo shim
  cat > "${bin_dir}/sudo" << 'SUDOEOF'
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
SUDOEOF
  chmod +x "${bin_dir}/sudo"
  run bash -c "
    export PATH='${bin_dir}:\${PATH}'
    source '${SCRIPTS_DIR}/.functions.bash'
    system::reload_sysctl_conf
  " <<< 'n'
  assert_success
  # sysctl shim should NOT have been called
  [[ ! -f "${calls_file}" ]]
}

@test "reload_sysctl_conf: dies with args" {
  run system::reload_sysctl_conf 'extra'
  assert_failure
  assert_output --partial 'Expected no arguments'
}
