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
  source "${SCRIPTS_DIR}/functions/dirs.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/prompt.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/files.bash"
}

# ---------- files::exists ----------

@test "exists: regular file -> true" {
  : > "${BATS_TEST_TMPDIR}/f"
  run files::exists "${BATS_TEST_TMPDIR}/f"
  assert_success
}

@test "exists: dir -> false" {
  mkdir --parents "${BATS_TEST_TMPDIR}/d"
  run files::exists "${BATS_TEST_TMPDIR}/d"
  assert_failure
}

@test "exists: missing -> false" {
  run files::exists "${BATS_TEST_TMPDIR}/nope"
  assert_failure
}

@test "exists: symlink to file -> true" {
  : > "${BATS_TEST_TMPDIR}/target"
  ln --symbolic "${BATS_TEST_TMPDIR}/target" "${BATS_TEST_TMPDIR}/link"
  run files::exists "${BATS_TEST_TMPDIR}/link"
  assert_success
}

@test "exists: broken symlink -> false" {
  ln --symbolic "${BATS_TEST_TMPDIR}/missing" "${BATS_TEST_TMPDIR}/broken"
  run files::exists "${BATS_TEST_TMPDIR}/broken"
  assert_failure
}

@test "exists: dies with 0 args" {
  run files::exists
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- files::assert_exists ----------

@test "assert_exists: file present -> success" {
  : > "${BATS_TEST_TMPDIR}/f"
  run files::assert_exists "${BATS_TEST_TMPDIR}/f"
  assert_success
}

@test "assert_exists: missing -> dies" {
  run files::assert_exists "${BATS_TEST_TMPDIR}/nope"
  assert_failure
  assert_output --partial 'does not exist'
}

# ---------- files::any_exists ----------

@test "any_exists: file -> true" {
  : > "${BATS_TEST_TMPDIR}/f"
  run files::any_exists "${BATS_TEST_TMPDIR}/f"
  assert_success
}

@test "any_exists: dir -> true" {
  mkdir --parents "${BATS_TEST_TMPDIR}/d"
  run files::any_exists "${BATS_TEST_TMPDIR}/d"
  assert_success
}

@test "any_exists: symlink (live) -> true" {
  : > "${BATS_TEST_TMPDIR}/t"
  ln --symbolic "${BATS_TEST_TMPDIR}/t" "${BATS_TEST_TMPDIR}/l"
  run files::any_exists "${BATS_TEST_TMPDIR}/l"
  assert_success
}

@test "any_exists: missing -> false" {
  run files::any_exists "${BATS_TEST_TMPDIR}/nope"
  assert_failure
}

# ---------- files::is_readable ----------

@test "is_readable: readable file -> true" {
  : > "${BATS_TEST_TMPDIR}/f"
  run files::is_readable "${BATS_TEST_TMPDIR}/f"
  assert_success
}

@test "is_readable: unreadable file -> false" {
  : > "${BATS_TEST_TMPDIR}/f"
  chmod 000 "${BATS_TEST_TMPDIR}/f"
  if [[ "$(id -u)" -eq 0 ]]; then
    skip 'root bypasses read perms'
  fi
  run files::is_readable "${BATS_TEST_TMPDIR}/f"
  assert_failure
  chmod 644 "${BATS_TEST_TMPDIR}/f"
}

@test "is_readable: missing -> false" {
  run files::is_readable "${BATS_TEST_TMPDIR}/nope"
  assert_failure
}

# ---------- files::size_gb ----------

@test "size_gb: tiny file -> 0 (bc with scale=2 omits trailing zeros for 0)" {
  : > "${BATS_TEST_TMPDIR}/f"
  run files::size_gb "${BATS_TEST_TMPDIR}/f"
  assert_success
  # bc outputs '0' for 0/N at scale=2; encode actual behavior, not idealized form.
  [[ "${output}" == '0' || "${output}" =~ ^[0-9]*\.[0-9]+$ || "${output}" =~ ^\.[0-9]+$ ]]
}

@test "size_gb: missing dies" {
  run files::size_gb "${BATS_TEST_TMPDIR}/nope"
  assert_failure
  assert_output --partial 'does not exist'
}

# ---------- files::hash ----------

@test "hash: known content -> known sha256" {
  printf '%s' 'hello' > "${BATS_TEST_TMPDIR}/f"
  run files::hash "${BATS_TEST_TMPDIR}/f"
  assert_success
  assert_output '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824'
}

@test "hash: missing file -> '0'" {
  run files::hash "${BATS_TEST_TMPDIR}/nope"
  assert_success
  assert_output '0'
}

# ---------- files::write (canonical) ----------

@test "write: nonexistent dest -> creates with content (auto-answer Y)" {
  # shellcheck disable=SC2030,SC2031
  export SCRIPTS_AUTO_ANSWER=y # intentional: export reaches child process via `run`
  files::write "${BATS_TEST_TMPDIR}/f" 'hello'
  [[ -f "${BATS_TEST_TMPDIR}/f" ]]
  [[ "$(< "${BATS_TEST_TMPDIR}/f")" == 'hello' ]]
}

@test "write: identical content short-circuits silently (no prompt needed)" {
  printf '%s\n' 'same' > "${BATS_TEST_TMPDIR}/f"
  run files::write "${BATS_TEST_TMPDIR}/f" 'same'
  assert_success
  [[ "$(< "${BATS_TEST_TMPDIR}/f")" == 'same' ]]
}

@test "write: different content with auto-answer Y -> overwrites" {
  printf '%s\n' 'old' > "${BATS_TEST_TMPDIR}/f"
  # shellcheck disable=SC2030,SC2031
  export SCRIPTS_AUTO_ANSWER=y # intentional: export reaches child process via `run`
  files::write "${BATS_TEST_TMPDIR}/f" 'new'
  [[ "$(< "${BATS_TEST_TMPDIR}/f")" == 'new' ]]
}

@test "write: different content with prompt rejected -> preserves old" {
  printf '%s\n' 'old' > "${BATS_TEST_TMPDIR}/f"
  run bash -c "
    source '${SCRIPTS_DIR}/functions.bash'
    files::write '${BATS_TEST_TMPDIR}/f' 'new'
  " <<< 'n'
  assert_success
  [[ "$(< "${BATS_TEST_TMPDIR}/f")" == 'old' ]]
}

@test "write: missing parent dir auto-created" {
  # shellcheck disable=SC2030,SC2031
  export SCRIPTS_AUTO_ANSWER=y # intentional: export reaches child process via `run`
  files::write "${BATS_TEST_TMPDIR}/a/b/c/f" 'content'
  [[ -f "${BATS_TEST_TMPDIR}/a/b/c/f" ]]
}

@test "write: emits Writing/Wrote on stderr" {
  # shellcheck disable=SC2030,SC2031
  export SCRIPTS_AUTO_ANSWER=y # intentional: export reaches child process via `run`
  run --separate-stderr files::write "${BATS_TEST_TMPDIR}/f" 'content'
  assert_success
  [[ "${stderr}" == *'Writing'* ]]
  [[ "${stderr}" == *'Wrote'* ]]
}

@test "write: dies with 1 arg" {
  run files::write 'a'
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "write: dies with 3 args" {
  run files::write 'a' 'b' 'c'
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

# ---------- files::write_quiet ----------

@test "write_quiet: works like write but no log lines" {
  # shellcheck disable=SC2030,SC2031
  export SCRIPTS_AUTO_ANSWER=y # intentional: export reaches child process via `run`
  run --separate-stderr files::write_quiet "${BATS_TEST_TMPDIR}/f" 'content'
  assert_success
  [[ "${stderr}" != *'Writing'* ]]
  [[ "${stderr}" != *'Wrote'* ]]
  [[ "$(< "${BATS_TEST_TMPDIR}/f")" == 'content' ]]
}

# ---------- files::move ----------

@test "move: src -> nonexistent dest with auto-answer Y" {
  printf '%s\n' 'data' > "${BATS_TEST_TMPDIR}/src"
  # shellcheck disable=SC2030,SC2031
  export SCRIPTS_AUTO_ANSWER=y # intentional: export reaches child process via `run`
  files::move "${BATS_TEST_TMPDIR}/src" "${BATS_TEST_TMPDIR}/dest"
  [[ ! -e "${BATS_TEST_TMPDIR}/src" ]]
  [[ "$(< "${BATS_TEST_TMPDIR}/dest")" == 'data' ]]
}

@test "move: byte-identical dest -> src removed, no prompt" {
  printf '%s\n' 'same' > "${BATS_TEST_TMPDIR}/src"
  printf '%s\n' 'same' > "${BATS_TEST_TMPDIR}/dest"
  run files::move "${BATS_TEST_TMPDIR}/src" "${BATS_TEST_TMPDIR}/dest"
  assert_success
  [[ ! -e "${BATS_TEST_TMPDIR}/src" ]]
  [[ "$(< "${BATS_TEST_TMPDIR}/dest")" == 'same' ]]
}

@test "move: different dest auto-answer Y -> overwrites" {
  printf '%s\n' 'new' > "${BATS_TEST_TMPDIR}/src"
  printf '%s\n' 'old' > "${BATS_TEST_TMPDIR}/dest"
  # shellcheck disable=SC2030,SC2031
  export SCRIPTS_AUTO_ANSWER=y # intentional: export reaches child process via `run`
  files::move "${BATS_TEST_TMPDIR}/src" "${BATS_TEST_TMPDIR}/dest"
  [[ "$(< "${BATS_TEST_TMPDIR}/dest")" == 'new' ]]
}

@test "move: src == dest dies" {
  : > "${BATS_TEST_TMPDIR}/x"
  run files::move "${BATS_TEST_TMPDIR}/x" "${BATS_TEST_TMPDIR}/x"
  assert_failure
  assert_output --partial 'File paths are the same'
}

@test "move: missing src dies" {
  run files::move "${BATS_TEST_TMPDIR}/nope" "${BATS_TEST_TMPDIR}/dest"
  assert_failure
  assert_output --partial 'does not exist'
}

@test "move: missing parent of dest auto-created" {
  : > "${BATS_TEST_TMPDIR}/src"
  # shellcheck disable=SC2030,SC2031
  export SCRIPTS_AUTO_ANSWER=y # intentional: export reaches child process via `run`
  files::move "${BATS_TEST_TMPDIR}/src" "${BATS_TEST_TMPDIR}/a/b/dest"
  [[ -f "${BATS_TEST_TMPDIR}/a/b/dest" ]]
}

@test "move: dies with 1 arg" {
  run files::move 'a'
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

# ---------- move variants ----------

@test "move_quiet: no log lines" {
  : > "${BATS_TEST_TMPDIR}/src"
  # shellcheck disable=SC2030,SC2031
  export SCRIPTS_AUTO_ANSWER=y # intentional: export reaches child process via `run`
  run --separate-stderr files::move_quiet "${BATS_TEST_TMPDIR}/src" "${BATS_TEST_TMPDIR}/dest"
  assert_success
  [[ "${stderr}" != *'Moving'* ]]
  [[ ! -e "${BATS_TEST_TMPDIR}/src" ]]
  [[ -f "${BATS_TEST_TMPDIR}/dest" ]]
}

@test "move_no_prompt: no auto-answer needed, overwrites unconditionally" {
  printf '%s\n' 'new' > "${BATS_TEST_TMPDIR}/src"
  printf '%s\n' 'old' > "${BATS_TEST_TMPDIR}/dest"
  unset SCRIPTS_AUTO_ANSWER || true
  files::move_no_prompt "${BATS_TEST_TMPDIR}/src" "${BATS_TEST_TMPDIR}/dest"
  [[ "$(< "${BATS_TEST_TMPDIR}/dest")" == 'new' ]]
}

@test "move_no_prompt: src == dest dies" {
  : > "${BATS_TEST_TMPDIR}/x"
  run files::move_no_prompt "${BATS_TEST_TMPDIR}/x" "${BATS_TEST_TMPDIR}/x"
  assert_failure
}

@test "move_no_prompt_quiet: no log lines and unconditional overwrite" {
  : > "${BATS_TEST_TMPDIR}/src"
  : > "${BATS_TEST_TMPDIR}/dest"
  unset SCRIPTS_AUTO_ANSWER || true
  run --separate-stderr files::move_no_prompt_quiet "${BATS_TEST_TMPDIR}/src" "${BATS_TEST_TMPDIR}/dest"
  assert_success
  [[ "${stderr}" != *'Moving'* ]]
  [[ ! -e "${BATS_TEST_TMPDIR}/src" ]]
}

# ---------- files::copy ----------

@test "copy: nonexistent dest auto-Y -> creates copy, src remains" {
  printf '%s\n' 'data' > "${BATS_TEST_TMPDIR}/src"
  # shellcheck disable=SC2030,SC2031
  export SCRIPTS_AUTO_ANSWER=y # intentional: export reaches child process via `run`
  files::copy "${BATS_TEST_TMPDIR}/src" "${BATS_TEST_TMPDIR}/dest"
  [[ -f "${BATS_TEST_TMPDIR}/src" ]]
  [[ "$(< "${BATS_TEST_TMPDIR}/dest")" == 'data' ]]
}

@test "copy: byte-identical dest -> short-circuit silently" {
  printf '%s\n' 'same' > "${BATS_TEST_TMPDIR}/src"
  printf '%s\n' 'same' > "${BATS_TEST_TMPDIR}/dest"
  run files::copy "${BATS_TEST_TMPDIR}/src" "${BATS_TEST_TMPDIR}/dest"
  assert_success
  [[ -f "${BATS_TEST_TMPDIR}/src" ]]
}

@test "copy: src == dest dies" {
  : > "${BATS_TEST_TMPDIR}/x"
  run files::copy "${BATS_TEST_TMPDIR}/x" "${BATS_TEST_TMPDIR}/x"
  assert_failure
  assert_output --partial 'File paths are the same'
}

@test "copy: missing src dies" {
  run files::copy "${BATS_TEST_TMPDIR}/nope" "${BATS_TEST_TMPDIR}/dest"
  assert_failure
  assert_output --partial 'does not exist'
}

@test "copy_quiet: no log lines" {
  : > "${BATS_TEST_TMPDIR}/src"
  # shellcheck disable=SC2030,SC2031
  export SCRIPTS_AUTO_ANSWER=y # intentional: export reaches child process via `run`
  run --separate-stderr files::copy_quiet "${BATS_TEST_TMPDIR}/src" "${BATS_TEST_TMPDIR}/dest"
  assert_success
  [[ "${stderr}" != *'Copying'* ]]
  [[ -f "${BATS_TEST_TMPDIR}/dest" ]]
}

# ---------- files::append_to ----------

@test "append_to: appends to existing file" {
  printf '%s\n' 'first' > "${BATS_TEST_TMPDIR}/f"
  files::append_to "${BATS_TEST_TMPDIR}/f" 'second'
  [[ "$(< "${BATS_TEST_TMPDIR}/f")" == $'first\nsecond' ]]
}

@test "append_to: creates file if missing" {
  files::append_to "${BATS_TEST_TMPDIR}/new" 'content'
  [[ -f "${BATS_TEST_TMPDIR}/new" ]]
  [[ "$(< "${BATS_TEST_TMPDIR}/new")" == 'content' ]]
}

@test "append_to: parent dir auto-created" {
  files::append_to "${BATS_TEST_TMPDIR}/a/b/f" 'content'
  [[ -f "${BATS_TEST_TMPDIR}/a/b/f" ]]
}

@test "append_to: emits Appending/Appended log lines" {
  run --separate-stderr files::append_to "${BATS_TEST_TMPDIR}/f" 'content'
  assert_success
  [[ "${stderr}" == *'Appending'* ]]
  [[ "${stderr}" == *'Appended'* ]]
}

@test "append_to_quiet: no log lines" {
  run --separate-stderr files::append_to_quiet "${BATS_TEST_TMPDIR}/f" 'content'
  assert_success
  [[ "${stderr}" != *'Appending'* ]]
  [[ "${stderr}" != *'Appended'* ]]
  [[ "$(< "${BATS_TEST_TMPDIR}/f")" == 'content' ]]
}

@test "append_to: dies with 1 arg" {
  run files::append_to 'a'
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

# ---------- root_* skipped (Phase G) ----------

@test "root_write: skipped (Phase G)" { skip 'requires sudo (Phase G)'; }
@test "root_write_quiet: skipped (Phase G)" { skip 'requires sudo (Phase G)'; }
@test "root_move: skipped (Phase G)" { skip 'requires sudo (Phase G)'; }
@test "root_move_quiet: skipped (Phase G)" { skip 'requires sudo (Phase G)'; }
@test "root_copy: skipped (Phase G)" { skip 'requires sudo (Phase G)'; }
@test "root_copy_quiet: skipped (Phase G)" { skip 'requires sudo (Phase G)'; }
@test "root_append_to: skipped (Phase G)" { skip 'requires sudo (Phase G)'; }
@test "root_append_to_quiet: skipped (Phase G)" { skip 'requires sudo (Phase G)'; }
