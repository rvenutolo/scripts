# shellcheck disable=SC2030,SC2031 # BATS isolates each @test in its own subshell; env mutations are scoped per-test
# shellcheck disable=SC2016,SC2088 # fixture text holds literal $VAR and ~ for the helper under test to expand

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/strings.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/dirs.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/files.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/commands.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/git.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/path.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/claude.bash"
  load '../test_helper/git_fixture'
  load '../test_helper/path_shim'

  REPO="${BATS_TEST_TMPDIR}/repo"
  PLAIN="${BATS_TEST_TMPDIR}/plain"
}

# Write $2 verbatim (no trailing newline added) to <dir>/.claude/wrapper-args.
# $1 = directory that holds the .claude dir
# $2 = file content
write_args_file() {
  local -r dir="$1"
  local -r content="$2"
  mkdir --parents -- "${dir}/.claude"
  printf '%s' "${content}" > "${dir}/.claude/wrapper-args"
}

# Create a fixture repo at REPO.
make_repo() {
  git_fixture::init "${REPO}"
}

# Stage (and optionally commit) REPO's root wrapper-args file. --force because a
# global excludes file may ignore .claude/; a committed file is the threat modelled.
# $1 = 'commit' to also commit, anything else to stage only
track_root_file() {
  local -r mode="$1"
  git_fixture::run "${REPO}" add --force -- .claude/wrapper-args
  if [[ "${mode}" == 'commit' ]]; then
    git_fixture::run "${REPO}" -c user.name=t -c user.email=t@example.invalid commit --quiet --message=x
  fi
}

# ---------- lookup and trust ----------

@test "wrapper_args: no file anywhere yields no args" {
  make_repo
  local -a got=()
  claude::wrapper_args got "${REPO}"
  assert_equal "${#got[@]}" 0
  run --separate-stderr claude::wrapper_args got "${REPO}"
  assert_success
  assert_stderr ''
}

@test "wrapper_args: reads an untracked file in the start dir" {
  make_repo
  write_args_file "${REPO}" '--model sonnet'
  local -a got=()
  claude::wrapper_args got "${REPO}"
  assert_equal "${#got[@]}" 2
  assert_equal "${got[0]}" '--model'
  assert_equal "${got[1]}" 'sonnet'
}

@test "wrapper_args: finds the file in an ancestor up to the repo root" {
  make_repo
  mkdir --parents -- "${REPO}/a/b"
  write_args_file "${REPO}" '--model sonnet'
  local -a got=()
  claude::wrapper_args got "${REPO}/a/b"
  assert_equal "${#got[@]}" 2
  assert_equal "${got[1]}" 'sonnet'
}

@test "wrapper_args: nearest file wins over the repo root's" {
  make_repo
  mkdir --parents -- "${REPO}/a"
  write_args_file "${REPO}" '--model root'
  write_args_file "${REPO}/a" '--model near'
  local -a got=()
  claude::wrapper_args got "${REPO}/a"
  assert_equal "${#got[@]}" 2
  assert_equal "${got[1]}" 'near'
}

@test "wrapper_args: ignores a file above the repo root" {
  make_repo
  write_args_file "${BATS_TEST_TMPDIR}" '--model above'
  local -a got=()
  claude::wrapper_args got "${REPO}"
  assert_equal "${#got[@]}" 0
}

@test "wrapper_args: treats a .git file as the repo root" {
  mkdir --parents -- "${PLAIN}/sub"
  printf '%s\n' 'gitdir: /nonexistent' > "${PLAIN}/.git"
  write_args_file "${PLAIN}" '--model sonnet'
  write_args_file "${BATS_TEST_TMPDIR}" '--model above'
  path_shim::add git $'#!/usr/bin/env bash\nexit 1'
  local -a got=()
  claude::wrapper_args got "${PLAIN}/sub"
  assert_equal "${#got[@]}" 2
  assert_equal "${got[1]}" 'sonnet'
}

@test "wrapper_args: outside a repo reads the start dir file" {
  mkdir --parents -- "${PLAIN}"
  write_args_file "${PLAIN}" '--model sonnet'
  local -a got=()
  claude::wrapper_args got "${PLAIN}"
  assert_equal "${#got[@]}" 2
  assert_equal "${got[1]}" 'sonnet'
}

@test "wrapper_args: outside a repo ignores a parent dir file" {
  mkdir --parents -- "${PLAIN}/child"
  write_args_file "${PLAIN}" '--model sonnet'
  local -a got=()
  claude::wrapper_args got "${PLAIN}/child"
  assert_equal "${#got[@]}" 0
}

@test "wrapper_args: ignores a committed file with a warning" {
  make_repo
  write_args_file "${REPO}" '--model sonnet'
  track_root_file commit
  local -a got=()
  claude::wrapper_args got "${REPO}" 2> '/dev/null'
  assert_equal "${#got[@]}" 0
  run --separate-stderr claude::wrapper_args got "${REPO}"
  assert_success
  assert_stderr --partial "${REPO}/.claude/wrapper-args"
  assert_stderr --partial 'tracked'
}

@test "wrapper_args: ignores a staged file with a warning" {
  make_repo
  write_args_file "${REPO}" '--model sonnet'
  track_root_file stage
  local -a got=()
  claude::wrapper_args got "${REPO}" 2> '/dev/null'
  assert_equal "${#got[@]}" 0
  run --separate-stderr claude::wrapper_args got "${REPO}"
  assert_stderr --partial "${REPO}/.claude/wrapper-args"
  assert_stderr --partial 'tracked'
}

@test "wrapper_args: ignores the file when git cannot answer" {
  make_repo
  write_args_file "${REPO}" '--model sonnet'
  path_shim::add git $'#!/usr/bin/env bash\nexit 128'
  local -a got=()
  claude::wrapper_args got "${REPO}" 2> '/dev/null'
  assert_equal "${#got[@]}" 0
  run --separate-stderr claude::wrapper_args got "${REPO}"
  assert_success
  assert_stderr --partial "${REPO}/.claude/wrapper-args"
  assert_stderr --partial 'could not verify'
}

@test "wrapper_args: a symlinked start dir still finds the committed file tracked" {
  make_repo
  mkdir --parents -- "${REPO}/sub"
  write_args_file "${REPO}/sub" '--model sonnet'
  git_fixture::run "${REPO}" add --force -- sub/.claude/wrapper-args
  git_fixture::run "${REPO}" -c user.name=t -c user.email=t@example.invalid commit --quiet --message=x
  ln --symbolic -- "${REPO}/sub" "${BATS_TEST_TMPDIR}/link"
  local -a got=()
  claude::wrapper_args got "${BATS_TEST_TMPDIR}/link" 2> '/dev/null'
  assert_equal "${#got[@]}" 0
  run --separate-stderr claude::wrapper_args got "${BATS_TEST_TMPDIR}/link"
  assert_stderr --partial 'tracked'
}

@test "wrapper_args: ignores a file reached through a committed .claude symlink" {
  make_repo
  mkdir --parents -- "${REPO}/vendor/x"
  printf '%s' '--model sonnet' > "${REPO}/vendor/x/wrapper-args"
  ln --symbolic -- 'vendor/x' "${REPO}/.claude"
  git_fixture::run "${REPO}" add --force -- .claude
  git_fixture::run "${REPO}" -c user.name=t -c user.email=t@example.invalid commit --quiet --message=x
  local -a got=()
  claude::wrapper_args got "${REPO}" 2> '/dev/null'
  assert_equal "${#got[@]}" 0
  run --separate-stderr claude::wrapper_args got "${REPO}"
  assert_success
  assert_stderr --partial "${REPO}/.claude/wrapper-args"
}

@test "wrapper_args: an exported GIT_DIR for another repo does not hide a tracked file" {
  make_repo
  write_args_file "${REPO}" '--model sonnet'
  track_root_file commit
  git_fixture::init "${BATS_TEST_TMPDIR}/other"
  export GIT_DIR="${BATS_TEST_TMPDIR}/other/.git"
  local -a got=()
  claude::wrapper_args got "${REPO}" 2> '/dev/null'
  assert_equal "${#got[@]}" 0
}

@test "wrapper_args: ignores an unreadable file with a warning" {
  mkdir --parents -- "${PLAIN}"
  write_args_file "${PLAIN}" '--model sonnet'
  chmod 000 -- "${PLAIN}/.claude/wrapper-args"
  local -a got=()
  claude::wrapper_args got "${PLAIN}" 2> '/dev/null'
  assert_equal "${#got[@]}" 0
  run --separate-stderr claude::wrapper_args got "${PLAIN}"
  assert_success
  assert_stderr --partial "${PLAIN}/.claude/wrapper-args"
  assert_stderr --partial 'not readable'
}

@test "wrapper_args: ignores the file with a warning when envsubst is missing" {
  mkdir --parents -- "${PLAIN}"
  write_args_file "${PLAIN}" '--model sonnet'
  local envsubst_dir
  envsubst_dir="$(dirname -- "$(command -v envsubst)")"
  path::remove "${envsubst_dir}"
  local -a got=()
  claude::wrapper_args got "${PLAIN}" 2> '/dev/null'
  assert_equal "${#got[@]}" 0
  run --separate-stderr claude::wrapper_args got "${PLAIN}"
  assert_success
  assert_stderr --partial 'envsubst'
}

# ---------- parsing ----------

@test "wrapper_args: blank file yields no args" {
  mkdir --parents -- "${PLAIN}"
  write_args_file "${PLAIN}" $'   \n'
  local -a got=()
  claude::wrapper_args got "${PLAIN}"
  assert_equal "${#got[@]}" 0
  run --separate-stderr claude::wrapper_args got "${PLAIN}"
  assert_stderr ''
}

@test "wrapper_args: empty file yields no args" {
  mkdir --parents -- "${PLAIN}"
  write_args_file "${PLAIN}" ''
  local -a got=()
  claude::wrapper_args got "${PLAIN}"
  assert_equal "${#got[@]}" 0
  run --separate-stderr claude::wrapper_args got "${PLAIN}"
  assert_stderr ''
}

@test "wrapper_args: honors double quotes, single quotes and backslash escapes" {
  mkdir --parents -- "${PLAIN}"
  write_args_file "${PLAIN}" $'--add-dir "/x/my dir" --p \'a "b" c\' --q a\\ b'
  local -a got=()
  claude::wrapper_args got "${PLAIN}"
  assert_equal "${#got[@]}" 6
  assert_equal "${got[1]}" '/x/my dir'
  assert_equal "${got[3]}" 'a "b" c'
  assert_equal "${got[5]}" 'a b'
}

@test "wrapper_args: treats newlines as whitespace" {
  mkdir --parents -- "${PLAIN}"
  write_args_file "${PLAIN}" $'--model sonnet\n--effort low\n'
  local -a got=()
  claude::wrapper_args got "${PLAIN}"
  assert_equal "${#got[@]}" 4
  assert_equal "${got[3]}" 'low'
}

@test "wrapper_args: expands exported variables" {
  mkdir --parents -- "${PLAIN}"
  export WA_DIR='/x/my dir'
  write_args_file "${PLAIN}" '--add-dir "$WA_DIR" --x "${WA_DIR}/y"'
  local -a got=()
  claude::wrapper_args got "${PLAIN}"
  assert_equal "${#got[@]}" 4
  assert_equal "${got[1]}" '/x/my dir'
  assert_equal "${got[3]}" '/x/my dir/y'
}

@test "wrapper_args: splits an unquoted variable value on spaces" {
  mkdir --parents -- "${PLAIN}"
  export WA_DIR='/x/my dir'
  write_args_file "${PLAIN}" '--add-dir $WA_DIR'
  local -a got=()
  claude::wrapper_args got "${PLAIN}"
  assert_equal "${#got[@]}" 3
  assert_equal "${got[1]}" '/x/my'
  assert_equal "${got[2]}" 'dir'
}

@test "wrapper_args: does not run command substitutions" {
  mkdir --parents -- "${PLAIN}"
  local -r marker="${BATS_TEST_TMPDIR}/PAYLOAD_RAN"
  write_args_file "${PLAIN}" "--p '\$(touch ${marker}) \`touch ${marker}\`'"
  local -a got=()
  claude::wrapper_args got "${PLAIN}"
  assert_equal "${#got[@]}" 2
  assert_equal "${got[1]}" "\$(touch ${marker}) \`touch ${marker}\`"
  assert [ ! -e "${marker}" ]
}

@test "wrapper_args: ignores the file when a variable is unset" {
  mkdir --parents -- "${PLAIN}"
  unset WA_UNSET_ZZ
  write_args_file "${PLAIN}" '--add-dir $WA_UNSET_ZZ/x'
  local -a got=()
  claude::wrapper_args got "${PLAIN}" 2> '/dev/null'
  assert_equal "${#got[@]}" 0
  run --separate-stderr claude::wrapper_args got "${PLAIN}"
  assert_success
  assert_stderr --partial 'WA_UNSET_ZZ'
  assert_stderr --partial "${PLAIN}/.claude/wrapper-args"
}

@test "wrapper_args: treats a non-exported variable as unset" {
  mkdir --parents -- "${PLAIN}"
  export -n WA_LOCAL 2> '/dev/null' || true # ensure not exported from a prior env
  WA_LOCAL='x'
  write_args_file "${PLAIN}" '--p $WA_LOCAL'
  local -a got=()
  claude::wrapper_args got "${PLAIN}" 2> '/dev/null'
  assert_equal "${#got[@]}" 0
  run --separate-stderr claude::wrapper_args got "${PLAIN}"
  assert_stderr --partial 'WA_LOCAL'
}

@test "wrapper_args: ignores the file on an unclosed quote" {
  mkdir --parents -- "${PLAIN}"
  write_args_file "${PLAIN}" '--p "abc'
  local -a got=()
  claude::wrapper_args got "${PLAIN}" 2> '/dev/null'
  assert_equal "${#got[@]}" 0
  run --separate-stderr claude::wrapper_args got "${PLAIN}"
  assert_success
  assert_stderr --partial "${PLAIN}/.claude/wrapper-args"
  assert_stderr --partial 'could not parse'
}

@test "wrapper_args: expands a lone tilde and a leading tilde slash" {
  mkdir --parents -- "${PLAIN}"
  write_args_file "${PLAIN}" '~ ~/x'
  local -a got=()
  claude::wrapper_args got "${PLAIN}"
  assert_equal "${#got[@]}" 2
  assert_equal "${got[0]}" "${HOME}"
  assert_equal "${got[1]}" "${HOME}/x"
}

@test "wrapper_args: leaves mid-argument and user tildes alone" {
  mkdir --parents -- "${PLAIN}"
  write_args_file "${PLAIN}" '--f=~/x ~root/y'
  local -a got=()
  claude::wrapper_args got "${PLAIN}"
  assert_equal "${#got[@]}" 2
  assert_equal "${got[0]}" '--f=~/x'
  assert_equal "${got[1]}" '~root/y'
}

# ---------- guards ----------

@test "wrapper_args: dies with no args" {
  run --separate-stderr claude::wrapper_args
  assert_failure 1
  assert_stderr --partial 'Expected exactly 2 arguments'
}

@test "wrapper_args: dies with one arg" {
  run --separate-stderr claude::wrapper_args got
  assert_failure 1
  assert_stderr --partial 'Expected exactly 2 arguments'
}

@test "wrapper_args: dies with three args" {
  run --separate-stderr claude::wrapper_args got "${PLAIN}" extra
  assert_failure 1
  assert_stderr --partial 'Expected exactly 2 arguments'
}

@test "wrapper_args: dies when the out name is the reserved nameref" {
  run --separate-stderr claude::wrapper_args __claude_wrapper_args_ref "${PLAIN}"
  assert_failure 1
  assert_stderr --partial "'__claude_wrapper_args_ref'"
}
