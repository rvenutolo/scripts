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
  source "${SCRIPTS_DIR}/functions/system.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/shell_scripts.bash"

  TREE="${BATS_TEST_TMPDIR}/tree"
  mkdir --parents "${TREE}/sub" "${TREE}/other"
  printf '%s\n' '#!/bin/bash' 'echo a' > "${TREE}/a.sh"
  printf '%s\n' '#!/usr/bin/env bash' 'echo b' > "${TREE}/b.bash"
  printf '%s\n' '#!/usr/bin/env bats' 'echo c' > "${TREE}/c.bats"
  printf '%s\n' 'no shebang here' > "${TREE}/d.txt"
  printf '%s\n' '#!/usr/bin/env python3' 'print("e")' > "${TREE}/e"
  printf '%s\n' '#!/usr/bin/env bash' 'echo f' > "${TREE}/f"
  printf '%s\n' '#!/usr/bin/env bash' 'echo g' > "${TREE}/sub/g.sh"
  printf '%s\n' '#!/usr/bin/env bash' 'echo other' > "${TREE}/other/h.sh"
  chmod +x "${TREE}"/{a.sh,b.bash,c.bats,e,f} "${TREE}/sub/g.sh" "${TREE}/other/h.sh"
}

# ---------- has_shell_shebang ----------

@test "has_shell_shebang: bash shebang -> true" {
  run shell_scripts::has_shell_shebang "${TREE}/b.bash"
  assert_success
}

@test "has_shell_shebang: sh shebang -> true" {
  run shell_scripts::has_shell_shebang "${TREE}/a.sh"
  assert_success
}

@test "has_shell_shebang: bats shebang -> true" {
  run shell_scripts::has_shell_shebang "${TREE}/c.bats"
  assert_success
}

@test "has_shell_shebang: python shebang -> false" {
  run shell_scripts::has_shell_shebang "${TREE}/e"
  assert_failure
}

@test "has_shell_shebang: no shebang -> false" {
  run shell_scripts::has_shell_shebang "${TREE}/d.txt"
  assert_failure
}

@test "has_shell_shebang: dies with 0 args" {
  run shell_scripts::has_shell_shebang
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- assert_paths_exist ----------

@test "assert_paths_exist: all exist -> silent success" {
  run shell_scripts::assert_paths_exist "${TREE}/a.sh" "${TREE}/b.bash"
  assert_success
  assert_output ''
}

@test "assert_paths_exist: dir input also valid" {
  run shell_scripts::assert_paths_exist "${TREE}"
  assert_success
}

@test "assert_paths_exist: missing path dies" {
  run shell_scripts::assert_paths_exist "${TREE}/a.sh" "${TREE}/nope"
  assert_failure
  assert_output --partial 'does not exist'
}

@test "assert_paths_exist: zero args -> success (variadic, no-op)" {
  run shell_scripts::assert_paths_exist
  assert_success
}

# ---------- find ----------

@test "find: dir arg returns recursive shell files" {
  run shell_scripts::find "${TREE}"
  assert_success
  [[ "${output}" == *"a.sh"* ]]
  [[ "${output}" == *"b.bash"* ]]
  [[ "${output}" == *"c.bats"* ]]
  [[ "${output}" == *"sub/g.sh"* ]]
  [[ "${output}" == *"f"* ]]
  [[ "${output}" != *"d.txt"* ]]
}

@test "find: file arg returns the file as-is" {
  run shell_scripts::find "${TREE}/a.sh"
  assert_success
  assert_output "${TREE}/a.sh"
}

@test "find: mixed file+dir args" {
  run shell_scripts::find "${TREE}/a.sh" "${TREE}/sub"
  assert_success
  [[ "${output}" == *"${TREE}/a.sh"* ]]
  [[ "${output}" == *"sub/g.sh"* ]]
}

# ---------- filter ----------

@test "filter: keeps shell-shebang files, drops non-shell" {
  local result=()
  shell_scripts::filter result "${TREE}/a.sh" "${TREE}/d.txt" "${TREE}/b.bash" "${TREE}/e"
  [[ "${#result[@]}" -eq 2 ]]
  [[ "${result[0]}" == "${TREE}/a.sh" ]]
  [[ "${result[1]}" == "${TREE}/b.bash" ]]
}

@test "filter: empty input -> empty output" {
  local result=()
  shell_scripts::filter result
  [[ "${#result[@]}" -eq 0 ]]
}

@test "filter: /other/ path under auto-answer N is dropped" {
  local result=()
  # prompt::ny default is N; auto_answer=y means accept N -> drop the file
  export SCRIPTS_AUTO_ANSWER=y
  shell_scripts::filter result "${TREE}/a.sh" "${TREE}/other/h.sh"
  [[ "${#result[@]}" -eq 1 ]]
  [[ "${result[0]}" == "${TREE}/a.sh" ]]
}

@test "filter: dies with 0 args" {
  run shell_scripts::filter
  assert_failure
  assert_output --partial 'Expected at least 1 argument'
}

# ---------- find_root_only ----------

@test "shell_scripts::find_root_only emits root-level shebang files only" {
  local fake_root="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "${fake_root}/main" "${fake_root}/install"
  printf '#!/usr/bin/env bash\n' > "${fake_root}/root-a"
  chmod +x "${fake_root}/root-a"
  printf '#!/usr/bin/env bash\n' > "${fake_root}/root-b"
  chmod +x "${fake_root}/root-b"
  printf 'not a script\n' > "${fake_root}/README"
  printf '#!/usr/bin/env bash\n' > "${fake_root}/main/m1"
  chmod +x "${fake_root}/main/m1"
  printf '#!/usr/bin/env bash\n' > "${fake_root}/install/i1"
  chmod +x "${fake_root}/install/i1"

  SCRIPTS_DIR="${fake_root}" run shell_scripts::find_root_only
  assert_success
  assert_line "${fake_root}/root-a"
  assert_line "${fake_root}/root-b"
  refute_line "${fake_root}/README"
  refute_line "${fake_root}/main/m1"
  refute_line "${fake_root}/install/i1"
}

@test "shell_scripts::find_root_only skips files without shebang" {
  local fake_root="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "${fake_root}"
  printf '#!/usr/bin/env bash\n' > "${fake_root}/with-shebang"
  chmod +x "${fake_root}/with-shebang"
  printf 'plain text\n' > "${fake_root}/no-shebang"
  chmod +x "${fake_root}/no-shebang"

  SCRIPTS_DIR="${fake_root}" run shell_scripts::find_root_only
  assert_success
  assert_line "${fake_root}/with-shebang"
  refute_line "${fake_root}/no-shebang"
}

@test "shell_scripts::find_root_only dies when called with any args" {
  run shell_scripts::find_root_only foo
  assert_failure
  assert_output --partial 'Expected no arguments'
}
