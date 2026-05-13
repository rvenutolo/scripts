#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/test/test_helper/cli_shim.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/strings.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/misc.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/dirs.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/prompt.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/files.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/downloads.bash"
}

# Drop a `download <url> <path>` shim that writes ${BATS_TEST_TMPDIR}/payload to $2
# and records its invocation. Caller must seed payload first.
install_download_shim() {
  path_shim::add download "$(
    cat << 'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${BATS_TEST_TMPDIR}/download.calls"
cp -- "${BATS_TEST_TMPDIR}/payload" "$2"
EOF
  )"
}

# ---------- download_and_cat ----------

@test "download_and_cat: prints downloaded content" {
  printf 'hello world\n' > "${BATS_TEST_TMPDIR}/payload"
  install_download_shim
  run downloads::download_and_cat 'https://example.com/foo'
  assert_success
  assert_output 'hello world'
}

@test "download_and_cat: invokes download with url + a temp path" {
  printf 'x\n' > "${BATS_TEST_TMPDIR}/payload"
  install_download_shim
  run downloads::download_and_cat 'https://example.com/foo'
  assert_success
  run cli_shim::calls download
  assert_output --partial 'https://example.com/foo'
}

@test "download_and_cat: dies with no args" {
  run downloads::download_and_cat
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "download_and_cat: dies with too many args" {
  run downloads::download_and_cat a b
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- download_to_temp_file ----------

@test "download_to_temp_file: prints temp file path containing downloaded content" {
  printf 'payload-xyz\n' > "${BATS_TEST_TMPDIR}/payload"
  install_download_shim
  run downloads::download_to_temp_file 'https://example.com/foo'
  assert_success
  [[ -n "${output}" ]]
}

@test "download_to_temp_file: dies with wrong arg count" {
  run downloads::download_to_temp_file
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
  run downloads::download_to_temp_file a b
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- download_and_run_script ----------

@test "download_and_run_script: downloads, chmods, runs script with no extra args" {
  cat > "${BATS_TEST_TMPDIR}/payload" << 'EOF'
#!/usr/bin/env bash
printf 'ran with: %s\n' "$*"
EOF
  install_download_shim
  run downloads::download_and_run_script 'https://example.com/install.sh'
  assert_success
  assert_output 'ran with: '
}

@test "download_and_run_script: forwards extra args to script" {
  cat > "${BATS_TEST_TMPDIR}/payload" << 'EOF'
#!/usr/bin/env bash
printf 'ran with: %s\n' "$*"
EOF
  install_download_shim
  run downloads::download_and_run_script 'https://example.com/install.sh' alpha beta
  assert_success
  assert_output 'ran with: alpha beta'
}

@test "download_and_run_script: dies with no args" {
  run downloads::download_and_run_script
  assert_failure
  assert_output --partial 'Expected at least 1 argument'
}

# ---------- download_and_run_script_as_root ----------

@test "download_and_run_script_as_root: runs via sudo passthrough" {
  cat > "${BATS_TEST_TMPDIR}/payload" << 'EOF'
#!/usr/bin/env bash
printf 'root-ran with: %s\n' "$*"
EOF
  install_download_shim
  cli_shim::install_passthrough_sudo
  run downloads::download_and_run_script_as_root 'https://example.com/install.sh' foo
  assert_success
  assert_output 'root-ran with: foo'
}

@test "download_and_run_script_as_root: dies with no args" {
  run downloads::download_and_run_script_as_root
  assert_failure
  assert_output --partial 'Expected at least 1 argument'
}
