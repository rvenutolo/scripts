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
  source "${SCRIPTS_DIR}/functions/files.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/dirs.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/prompt.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/symlinks.bash"
}

# ---------- symlinks::exists ----------

@test "exists: real symlink -> true" {
  : > "${BATS_TEST_TMPDIR}/target"
  ln --symbolic "${BATS_TEST_TMPDIR}/target" "${BATS_TEST_TMPDIR}/link"
  run symlinks::exists "${BATS_TEST_TMPDIR}/link"
  assert_success
}

@test "exists: regular file -> false" {
  : > "${BATS_TEST_TMPDIR}/file"
  run symlinks::exists "${BATS_TEST_TMPDIR}/file"
  assert_failure
}

@test "exists: dir -> false" {
  mkdir --parents "${BATS_TEST_TMPDIR}/dir"
  run symlinks::exists "${BATS_TEST_TMPDIR}/dir"
  assert_failure
}

@test "exists: nonexistent -> false" {
  run symlinks::exists "${BATS_TEST_TMPDIR}/nope"
  assert_failure
}

@test "exists: broken symlink -> true (test -L is true even if target missing)" {
  ln --symbolic "${BATS_TEST_TMPDIR}/missing" "${BATS_TEST_TMPDIR}/broken"
  run symlinks::exists "${BATS_TEST_TMPDIR}/broken"
  assert_success
}

@test "exists: dies with 0 args" {
  run symlinks::exists
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- symlinks::get_target ----------

@test "get_target: returns symlink target" {
  : > "${BATS_TEST_TMPDIR}/target"
  ln --symbolic "${BATS_TEST_TMPDIR}/target" "${BATS_TEST_TMPDIR}/link"
  run symlinks::get_target "${BATS_TEST_TMPDIR}/link"
  assert_success
  assert_output "${BATS_TEST_TMPDIR}/target"
}

@test "get_target: broken symlink returns target string anyway" {
  ln --symbolic '/nonexistent/target/path' "${BATS_TEST_TMPDIR}/broken"
  run symlinks::get_target "${BATS_TEST_TMPDIR}/broken"
  assert_success
  assert_output '/nonexistent/target/path'
}

@test "get_target: regular file dies" {
  : > "${BATS_TEST_TMPDIR}/file"
  run symlinks::get_target "${BATS_TEST_TMPDIR}/file"
  assert_failure
  assert_output --partial 'Symbolic link does not exist'
}

@test "get_target: nonexistent dies" {
  run symlinks::get_target "${BATS_TEST_TMPDIR}/nope"
  assert_failure
  assert_output --partial 'Symbolic link does not exist'
}

@test "get_target: dies with 0 args" {
  run symlinks::get_target
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- symlinks::link_file ----------

@test "link_file: fresh link is created" {
  : > "${BATS_TEST_TMPDIR}/src"
  SCRIPTS_AUTO_ANSWER=y symlinks::link_file "${BATS_TEST_TMPDIR}/src" "${BATS_TEST_TMPDIR}/link"
  [[ -L "${BATS_TEST_TMPDIR}/link" ]]
  [[ "$(readlink "${BATS_TEST_TMPDIR}/link")" == "${BATS_TEST_TMPDIR}/src" ]]
}

@test "link_file: already-correct link short-circuits (no prompt needed)" {
  : > "${BATS_TEST_TMPDIR}/src"
  ln --symbolic "${BATS_TEST_TMPDIR}/src" "${BATS_TEST_TMPDIR}/link"
  run symlinks::link_file "${BATS_TEST_TMPDIR}/src" "${BATS_TEST_TMPDIR}/link"
  assert_success
  [[ "$(readlink "${BATS_TEST_TMPDIR}/link")" == "${BATS_TEST_TMPDIR}/src" ]]
}

@test "link_file: existing-but-different link gets relinked under auto-answer" {
  : > "${BATS_TEST_TMPDIR}/src"
  : > "${BATS_TEST_TMPDIR}/other"
  ln --symbolic "${BATS_TEST_TMPDIR}/other" "${BATS_TEST_TMPDIR}/link"
  SCRIPTS_AUTO_ANSWER=y symlinks::link_file "${BATS_TEST_TMPDIR}/src" "${BATS_TEST_TMPDIR}/link"
  [[ "$(readlink "${BATS_TEST_TMPDIR}/link")" == "${BATS_TEST_TMPDIR}/src" ]]
}

@test "link_file: missing parent dir of link is auto-created" {
  : > "${BATS_TEST_TMPDIR}/src"
  SCRIPTS_AUTO_ANSWER=y symlinks::link_file "${BATS_TEST_TMPDIR}/src" "${BATS_TEST_TMPDIR}/sub/dir/link"
  [[ -L "${BATS_TEST_TMPDIR}/sub/dir/link" ]]
}

@test "link_file: nonexistent target dies" {
  SCRIPTS_AUTO_ANSWER=y run symlinks::link_file "${BATS_TEST_TMPDIR}/nope" "${BATS_TEST_TMPDIR}/link"
  assert_failure
  assert_output --partial 'does not exist'
}

@test "link_file: dies with 1 arg" {
  run symlinks::link_file "${BATS_TEST_TMPDIR}/src"
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "link_file: dies with 3 args" {
  run symlinks::link_file 'a' 'b' 'c'
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

# ---------- symlinks::link_dir ----------

@test "link_dir: fresh link to dir is created" {
  mkdir --parents "${BATS_TEST_TMPDIR}/srcdir"
  SCRIPTS_AUTO_ANSWER=y symlinks::link_dir "${BATS_TEST_TMPDIR}/srcdir" "${BATS_TEST_TMPDIR}/linkdir"
  [[ -L "${BATS_TEST_TMPDIR}/linkdir" ]]
}

@test "link_dir: already-correct link short-circuits" {
  mkdir --parents "${BATS_TEST_TMPDIR}/srcdir"
  ln --symbolic "${BATS_TEST_TMPDIR}/srcdir" "${BATS_TEST_TMPDIR}/linkdir"
  run symlinks::link_dir "${BATS_TEST_TMPDIR}/srcdir" "${BATS_TEST_TMPDIR}/linkdir"
  assert_success
}

@test "link_dir: existing-but-different gets relinked under auto-answer" {
  mkdir --parents "${BATS_TEST_TMPDIR}/src1" "${BATS_TEST_TMPDIR}/src2"
  ln --symbolic "${BATS_TEST_TMPDIR}/src2" "${BATS_TEST_TMPDIR}/linkdir"
  SCRIPTS_AUTO_ANSWER=y symlinks::link_dir "${BATS_TEST_TMPDIR}/src1" "${BATS_TEST_TMPDIR}/linkdir"
  [[ "$(readlink "${BATS_TEST_TMPDIR}/linkdir")" == "${BATS_TEST_TMPDIR}/src1" ]]
}

@test "link_dir: nonexistent target dies" {
  SCRIPTS_AUTO_ANSWER=y run symlinks::link_dir "${BATS_TEST_TMPDIR}/nope" "${BATS_TEST_TMPDIR}/linkdir"
  assert_failure
  assert_output --partial 'does not exist'
}

@test "link_dir: dies with 1 arg" {
  run symlinks::link_dir 'a'
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

# ---------- symlinks::points_at ----------

@test "points_at: link does not exist -> false" {
  : > "${BATS_TEST_TMPDIR}/target"
  run symlinks::points_at "${BATS_TEST_TMPDIR}/nonexistent_link" "${BATS_TEST_TMPDIR}/target"
  assert_failure
}

@test "points_at: path is a regular file, not a symlink -> false" {
  : > "${BATS_TEST_TMPDIR}/file"
  : > "${BATS_TEST_TMPDIR}/target"
  run symlinks::points_at "${BATS_TEST_TMPDIR}/file" "${BATS_TEST_TMPDIR}/target"
  assert_failure
}

@test "points_at: link points at the named target -> true" {
  : > "${BATS_TEST_TMPDIR}/target"
  ln --symbolic "${BATS_TEST_TMPDIR}/target" "${BATS_TEST_TMPDIR}/link"
  run symlinks::points_at "${BATS_TEST_TMPDIR}/link" "${BATS_TEST_TMPDIR}/target"
  assert_success
}

@test "points_at: link points at a different target -> false" {
  : > "${BATS_TEST_TMPDIR}/target"
  : > "${BATS_TEST_TMPDIR}/other"
  ln --symbolic "${BATS_TEST_TMPDIR}/other" "${BATS_TEST_TMPDIR}/link"
  run symlinks::points_at "${BATS_TEST_TMPDIR}/link" "${BATS_TEST_TMPDIR}/target"
  assert_failure
}

@test "points_at: link points at a directory target -> true" {
  mkdir --parents "${BATS_TEST_TMPDIR}/targetdir"
  ln --symbolic "${BATS_TEST_TMPDIR}/targetdir" "${BATS_TEST_TMPDIR}/link"
  run symlinks::points_at "${BATS_TEST_TMPDIR}/link" "${BATS_TEST_TMPDIR}/targetdir"
  assert_success
}

@test "points_at: broken link (target missing) -> readlink --canonicalize returns best-effort path; link does not match nonexistent target" {
  # readlink --canonicalize resolves as much as possible even for missing paths.
  # A broken link pointing at /nonexistent/path should NOT match a different nonexistent path.
  ln --symbolic "${BATS_TEST_TMPDIR}/missing_a" "${BATS_TEST_TMPDIR}/broken_link"
  run symlinks::points_at "${BATS_TEST_TMPDIR}/broken_link" "${BATS_TEST_TMPDIR}/missing_b"
  assert_failure
}

@test "points_at: broken link pointing at its own missing target -> true (canonical paths agree)" {
  # readlink --canonicalize on a broken link returns the absolute target path even if it doesn't exist.
  # So a broken link pointing at /tmp/x is considered to point_at /tmp/x.
  ln --symbolic "${BATS_TEST_TMPDIR}/missing_target" "${BATS_TEST_TMPDIR}/broken_link"
  run symlinks::points_at "${BATS_TEST_TMPDIR}/broken_link" "${BATS_TEST_TMPDIR}/missing_target"
  assert_success
}

@test "points_at: target given with trailing slash vs link without -> canonical comparison handles it" {
  mkdir --parents "${BATS_TEST_TMPDIR}/targetdir"
  ln --symbolic "${BATS_TEST_TMPDIR}/targetdir" "${BATS_TEST_TMPDIR}/link"
  # readlink --canonicalize strips trailing slashes; both should resolve the same
  run symlinks::points_at "${BATS_TEST_TMPDIR}/link" "${BATS_TEST_TMPDIR}/targetdir/"
  assert_success
}

@test "points_at: dies with 0 args" {
  run symlinks::points_at
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "points_at: dies with 1 arg" {
  run symlinks::points_at 'a'
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "points_at: dies with 3 args" {
  run symlinks::points_at 'a' 'b' 'c'
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}
