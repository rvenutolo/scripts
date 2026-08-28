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

# Write a per-test fixture under BATS_TEST_TMPDIR and echo its path. Kept out of
# setup()'s TREE on purpose: the shell_scripts::find tests assert on TREE's exact
# contents, so adding files there would break them.
make_fixture() {
  local -r name="$1"
  local -r contents="${2:-}"
  local -r path="${BATS_TEST_TMPDIR}/fixtures/${name}"
  mkdir --parents "$(dirname "${path}")"
  printf '%s' "${contents}" > "${path}"
  printf '%s\n' "${path}"
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
  assert_output --partial 'a.sh'
  assert_output --partial 'b.bash'
  assert_output --partial 'c.bats'
  assert_output --partial 'sub/g.sh'
  assert_output --partial "${TREE}/f"
  refute_output --partial 'd.txt'
}

@test "find: file arg returns the file as-is" {
  run shell_scripts::find "${TREE}/a.sh"
  assert_success
  assert_output "${TREE}/a.sh"
}

@test "find: mixed file+dir args" {
  run shell_scripts::find "${TREE}/a.sh" "${TREE}/sub"
  assert_success
  assert_output --partial "${TREE}/a.sh"
  assert_output --partial 'sub/g.sh'
}

@test "find: no args scans REPO_DIR and excludes other/, .shdoc/ and .direnv/" {
  local root="${BATS_TEST_TMPDIR}/repo"
  mkdir --parents "${root}/sub" "${root}/other" "${root}/.shdoc" "${root}/.direnv"
  printf '%s\n' '#!/usr/bin/env bash' 'echo keep' > "${root}/keep.sh"
  printf '%s\n' '#!/usr/bin/env bash' 'echo nested' > "${root}/sub/nested.sh"
  printf '%s\n' '#!/usr/bin/env bash' 'echo third-party' > "${root}/other/third.sh"
  printf '%s\n' '#!/usr/bin/env bash' 'echo vendored' > "${root}/.shdoc/vendored.sh"
  printf '%s\n' '#!/usr/bin/env bash' 'echo cached' > "${root}/.direnv/cached.sh"

  REPO_DIR="${root}" run shell_scripts::find
  assert_success
  assert_output --partial 'keep.sh'
  assert_output --partial 'sub/nested.sh'
  refute_output --partial 'third.sh'
  refute_output --partial 'vendored.sh'
  refute_output --partial 'cached.sh'
}

# Both no-args enumerators fail loudly on an empty result rather than emitting
# nothing: a caller that scans a tree and finds no shell files has almost
# certainly been pointed at the wrong tree, and a silent empty result there
# reads as a clean pass over code that was never examined. find gets this from
# the trailing `grep --invert-match`; find_root_only counts what it emitted.
@test "find: no args over a repo root with no shell files emits nothing and exits 1" {
  local root="${BATS_TEST_TMPDIR}/empty-repo"
  mkdir --parents "${root}"
  printf '%s\n' 'plain text' > "${root}/notes.txt"

  REPO_DIR="${root}" run shell_scripts::find
  assert_failure 1
  refute_output
}

# ---------- filter ----------

@test "filter: keeps shell files, drops non-shell" {
  local result=()
  shell_scripts::filter result "${TREE}/a.sh" "${TREE}/d.txt" "${TREE}/b.bash" "${TREE}/e"
  [[ "${#result[@]}" -eq 2 ]]
  [[ "${result[0]}" == "${TREE}/a.sh" ]]
  [[ "${result[1]}" == "${TREE}/b.bash" ]]
}

@test "filter: keeps a .bats file with no shebang" {
  local fixture
  fixture="$(make_fixture 'i.bats' 'setup() {
  true
}')"
  local result=()
  shell_scripts::filter result "${fixture}"
  [[ "${#result[@]}" -eq 1 ]]
  [[ "${result[0]}" == "${fixture}" ]]
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

  REPO_DIR="${fake_root}" run shell_scripts::find_root_only
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

  REPO_DIR="${fake_root}" run shell_scripts::find_root_only
  assert_success
  assert_line "${fake_root}/with-shebang"
  refute_line "${fake_root}/no-shebang"
}

@test "shell_scripts::find_root_only emits nothing and exits 1 when repo root has no top-level shell scripts" {
  local fake_root="${BATS_TEST_TMPDIR}/empty_repo"
  mkdir -p "${fake_root}/main"
  printf 'plain text\n' > "${fake_root}/README"
  printf '#!/usr/bin/env bash\n' > "${fake_root}/main/m1"
  chmod +x "${fake_root}/main/m1"

  REPO_DIR="${fake_root}" run shell_scripts::find_root_only
  assert_failure 1
  refute_output
}

@test "shell_scripts::find_root_only excludes .functions.bash loader" {
  local fake_root="${BATS_TEST_TMPDIR}/repo_with_loader"
  mkdir -p "${fake_root}"
  printf '#!/usr/bin/env bash\n' > "${fake_root}/.functions.bash"
  printf '#!/usr/bin/env bash\n' > "${fake_root}/legit-script"
  chmod +x "${fake_root}/legit-script"

  REPO_DIR="${fake_root}" run shell_scripts::find_root_only
  assert_success
  assert_line "${fake_root}/legit-script"
  refute_line "${fake_root}/.functions.bash"
}

@test "shell_scripts::find_root_only excludes every dotfile, loader or not" {
  local fake_root="${BATS_TEST_TMPDIR}/repo_with_dotfiles"
  mkdir -p "${fake_root}"
  printf '#!/usr/bin/env bash\n' > "${fake_root}/.envrc"
  printf '#!/usr/bin/env bash\n' > "${fake_root}/.hidden-script"
  printf '#!/usr/bin/env bash\n' > "${fake_root}/visible-script"
  chmod +x "${fake_root}/.hidden-script" "${fake_root}/visible-script"

  REPO_DIR="${fake_root}" run shell_scripts::find_root_only
  assert_success
  assert_line "${fake_root}/visible-script"
  refute_output --partial '/.envrc'
  refute_output --partial '/.hidden-script'
}

@test "shell_scripts::find_root_only dies when called with any args" {
  run shell_scripts::find_root_only foo
  assert_failure
  assert_output --partial 'Expected no arguments'
}

# ---------- is_shell_file ----------

@test "is_shell_file: .sh extension -> true" {
  run shell_scripts::is_shell_file "$(make_fixture 'plain.sh' 'echo hi')"
  assert_success
}

@test "is_shell_file: .bash extension -> true" {
  run shell_scripts::is_shell_file "$(make_fixture 'plain.bash' 'echo hi')"
  assert_success
}

@test "is_shell_file: .bats extension with no shebang -> true" {
  # The binding case for the whole design: .bats files open with @test, not a
  # shebang, and must still reach shfmt.
  run shell_scripts::is_shell_file "$(make_fixture 'suite.bats' '@test "x" { true; }')"
  assert_success
}

@test "is_shell_file: extensionless with bash shebang -> true" {
  run shell_scripts::is_shell_file "${TREE}/f"
  assert_success
}

@test "is_shell_file: extensionless with sh shebang -> true" {
  run shell_scripts::is_shell_file "$(make_fixture 'shrunner' '#!/bin/sh
echo hi')"
  assert_success
}

@test "is_shell_file: extensionless with bats shebang -> true" {
  run shell_scripts::is_shell_file "$(make_fixture 'batsrunner' '#!/usr/bin/env bats
@test "x" { true; }')"
  assert_success
}

@test "is_shell_file: markdown -> false" {
  run shell_scripts::is_shell_file "$(make_fixture 'README.md' '# Title

Some (parenthesized) prose.')"
  assert_failure
}

@test "is_shell_file: yaml -> false" {
  run shell_scripts::is_shell_file "$(make_fixture 'conf.yml' 'key: value')"
  assert_failure
}

@test "is_shell_file: json -> false" {
  run shell_scripts::is_shell_file "$(make_fixture 'data.json' '{"key": "value"}')"
  assert_failure
}

@test "is_shell_file: extensionless with no shebang -> false" {
  run shell_scripts::is_shell_file "${TREE}/d.txt"
  assert_failure
}

@test "is_shell_file: extensionless with non-shell shebang -> false" {
  run shell_scripts::is_shell_file "${TREE}/e"
  assert_failure
}

@test "is_shell_file: empty file -> false" {
  # head on zero bytes must not explode under the parent's strict mode.
  run shell_scripts::is_shell_file "$(make_fixture 'empty' '')"
  assert_failure
}

@test "is_shell_file: uppercase .SH is not a shell file" {
  # Case-sensitive on purpose: shfmt --find is case-sensitive, and this
  # predicate exists to mirror it. Asserted so the choice is recorded.
  run shell_scripts::is_shell_file "$(make_fixture 'LOUD.SH' 'echo hi')"
  assert_failure
}

@test "is_shell_file: judges the filename, not a directory ending in .sh" {
  run shell_scripts::is_shell_file "$(make_fixture 'dir.sh/runner' 'no shebang')"
  assert_failure
}

@test "is_shell_file: dies with no args" {
  run shell_scripts::is_shell_file
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "is_shell_file: dies with 2 args" {
  run shell_scripts::is_shell_file 'a' 'b'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "shell_scripts::requires_help_flag true when library sourced and no marker" {
  local f="${BATS_TEST_TMPDIR}/r1"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

set -Eeuo pipefail

source "${SCRIPTS_DIR}/.functions.bash"
log::enable_err_trap
args::check_no_args "$@"
EOF
  run shell_scripts::requires_help_flag "${f}"
  assert_success
}

@test "shell_scripts::requires_help_flag false for a pass-through script" {
  local f="${BATS_TEST_TMPDIR}/r2"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

set -Eeuo pipefail

source "${SCRIPTS_DIR}/.functions.bash"
log::enable_err_trap
# pass-through: any arg count valid (forwarded to the real kate binary)

exec kate "$@"
EOF
  run shell_scripts::requires_help_flag "${f}"
  assert_failure
}

@test "shell_scripts::requires_help_flag false when marker is a trailing comment" {
  local f="${BATS_TEST_TMPDIR}/r3"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

set -Eeuo pipefail

source "${SCRIPTS_DIR}/.functions.bash"
exec mvn "$@" # pass-through: maven owns its own --help
EOF
  run shell_scripts::requires_help_flag "${f}"
  assert_failure
}

@test "shell_scripts::requires_help_flag false when the library is never sourced" {
  local f="${BATS_TEST_TMPDIR}/r4"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

set -Eeuo pipefail

echo standalone
EOF
  run shell_scripts::requires_help_flag "${f}"
  assert_failure
}

@test "shell_scripts::requires_help_flag false when only ~/.profile is sourced" {
  local f="${BATS_TEST_TMPDIR}/r5"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

set -Eeuo pipefail

source "${HOME}/.profile"
echo standalone
EOF
  run shell_scripts::requires_help_flag "${f}"
  assert_failure
}

@test "shell_scripts::requires_help_flag true for a docker-compose functions.bash consumer" {
  local f="${BATS_TEST_TMPDIR}/r6"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

set -Eeuo pipefail

source "${DOCKER_COMPOSE_DIR}/functions.bash"
log::enable_err_trap
EOF
  run shell_scripts::requires_help_flag "${f}"
  assert_success
}

@test "shell_scripts::requires_help_flag dies with 0 args" {
  run shell_scripts::requires_help_flag
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "shell_scripts::requires_help_flag dies with 2 args" {
  run shell_scripts::requires_help_flag a b
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "filter: the reserved out-array nameref name is refused" {
  run --separate-stderr shell_scripts::filter '__shell_scripts_filter_ref' "${TREE}/a.sh"
  assert_failure 1
  assert_stderr --partial "out-parameter may not be named '__shell_scripts_filter_ref'"
}

@test "filter: a caller array named _out_ref works" {
  # _out_ref was the internal nameref name before the convention: passing it silently
  # yielded an empty array at exit 0, with only a bash warning on stderr.
  local -a _out_ref=()
  shell_scripts::filter _out_ref "${TREE}/a.sh"
  assert_equal "${#_out_ref[@]}" 1
  assert_equal "${_out_ref[0]}" "${TREE}/a.sh"
}
