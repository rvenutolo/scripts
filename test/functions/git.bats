#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/strings.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/files.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/dirs.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/commands.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/misc.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/prompt.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/git.bash"
}

# Create a repo at ${BATS_TEST_TMPDIR}/repo with commits made under different
# author/committer identities. Mix of author-only vs committer-only differences.
function _seed_repo_multi_idents() {
  local -r repo="${BATS_TEST_TMPDIR}/repo"
  git init --quiet --initial-branch=main "${repo}"
  git -C "${repo}" config commit.gpgSign false
  git -C "${repo}" config tag.gpgSign false

  # commit 1: author = Alice, committer = Alice
  GIT_AUTHOR_NAME='Alice' GIT_AUTHOR_EMAIL='alice@example.com' \
    GIT_COMMITTER_NAME='Alice' GIT_COMMITTER_EMAIL='alice@example.com' \
    git -C "${repo}" commit --quiet --allow-empty --message='c1'

  # commit 2: author = Alice, committer = GitHub
  GIT_AUTHOR_NAME='Alice' GIT_AUTHOR_EMAIL='alice@example.com' \
    GIT_COMMITTER_NAME='GitHub' GIT_COMMITTER_EMAIL='noreply@github.com' \
    git -C "${repo}" commit --quiet --allow-empty --message='c2'

  # commit 3: author = Bob, committer = Alice
  GIT_AUTHOR_NAME='Bob' GIT_AUTHOR_EMAIL='bob@example.com' \
    GIT_COMMITTER_NAME='Alice' GIT_COMMITTER_EMAIL='alice@example.com' \
    git -C "${repo}" commit --quiet --allow-empty --message='c3'

  # commit 4: author = Bob, committer = Bob
  GIT_AUTHOR_NAME='Bob' GIT_AUTHOR_EMAIL='bob@example.com' \
    GIT_COMMITTER_NAME='Bob' GIT_COMMITTER_EMAIL='bob@example.com' \
    git -C "${repo}" commit --quiet --allow-empty --message='c4'

  printf '%s\n' "${repo}"
}

# ---------- git::is_git_repo ----------

@test "is_git_repo: freshly inited repo -> true" {
  git -C "${BATS_TEST_TMPDIR}" init --quiet
  run git::is_git_repo "${BATS_TEST_TMPDIR}"
  assert_success
}

@test "is_git_repo: subdir of repo -> true" {
  git -C "${BATS_TEST_TMPDIR}" init --quiet
  mkdir --parents "${BATS_TEST_TMPDIR}/sub/nested"
  run git::is_git_repo "${BATS_TEST_TMPDIR}/sub/nested"
  assert_success
}

@test "is_git_repo: bare repo -> true" {
  local bare="${BATS_TEST_TMPDIR}/bare.git"
  git init --bare --quiet "${bare}"
  run git::is_git_repo "${bare}"
  assert_success
}

@test "is_git_repo: non-repo dir -> false" {
  mkdir --parents "${BATS_TEST_TMPDIR}/plain"
  run git::is_git_repo "${BATS_TEST_TMPDIR}/plain"
  assert_failure
}

@test "is_git_repo: nonexistent path -> false" {
  run git::is_git_repo "${BATS_TEST_TMPDIR}/nope"
  assert_failure
}

@test "is_git_repo: regular file -> false" {
  : > "${BATS_TEST_TMPDIR}/afile"
  run git::is_git_repo "${BATS_TEST_TMPDIR}/afile"
  assert_failure
}

@test "is_git_repo: dies with 0 args" {
  run git::is_git_repo
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "is_git_repo: dies with 2 args" {
  run git::is_git_repo 'a' 'b'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- git::assert_git_repo ----------

@test "assert_git_repo: repo -> silent success" {
  git -C "${BATS_TEST_TMPDIR}" init --quiet
  run git::assert_git_repo "${BATS_TEST_TMPDIR}"
  assert_success
  assert_output ''
}

@test "assert_git_repo: subdir of repo -> silent success" {
  git -C "${BATS_TEST_TMPDIR}" init --quiet
  mkdir --parents "${BATS_TEST_TMPDIR}/sub"
  run git::assert_git_repo "${BATS_TEST_TMPDIR}/sub"
  assert_success
  assert_output ''
}

@test "assert_git_repo: bare repo -> silent success" {
  local bare="${BATS_TEST_TMPDIR}/bare.git"
  git init --bare --quiet "${bare}"
  run git::assert_git_repo "${bare}"
  assert_success
  assert_output ''
}

@test "assert_git_repo: non-repo dir -> dies" {
  mkdir --parents "${BATS_TEST_TMPDIR}/plain"
  run git::assert_git_repo "${BATS_TEST_TMPDIR}/plain"
  assert_failure
  assert_output --partial 'is not a git repo'
}

@test "assert_git_repo: nonexistent path -> dies" {
  run git::assert_git_repo "${BATS_TEST_TMPDIR}/nope"
  assert_failure
  assert_output --partial 'is not a git repo'
}

@test "assert_git_repo: dies with 0 args" {
  run git::assert_git_repo
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "assert_git_repo: dies with 2 args" {
  run git::assert_git_repo 'a' 'b'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- git::repo_root ----------

@test "repo_root: returns toplevel from repo root" {
  git -C "${BATS_TEST_TMPDIR}" init --quiet
  run git::repo_root "${BATS_TEST_TMPDIR}"
  assert_success
  assert_output "$(cd "${BATS_TEST_TMPDIR}" && pwd -P)"
}

@test "repo_root: returns toplevel from subdir" {
  git -C "${BATS_TEST_TMPDIR}" init --quiet
  mkdir --parents "${BATS_TEST_TMPDIR}/sub/nested"
  run git::repo_root "${BATS_TEST_TMPDIR}/sub/nested"
  assert_success
  assert_output "$(cd "${BATS_TEST_TMPDIR}" && pwd -P)"
}

@test "repo_root: non-repo -> dies" {
  mkdir --parents "${BATS_TEST_TMPDIR}/plain"
  run git::repo_root "${BATS_TEST_TMPDIR}/plain"
  assert_failure
  assert_output --partial 'is not a git repo'
}

@test "repo_root: dies with 0 args" {
  run git::repo_root
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "repo_root: dies with 2 args" {
  run git::repo_root 'a' 'b'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- git::canonical_name ----------

@test "canonical_name: returns configured name" {
  git -C "${BATS_TEST_TMPDIR}" init --quiet
  git -C "${BATS_TEST_TMPDIR}" config user.name 'Test User'
  run git::canonical_name "${BATS_TEST_TMPDIR}"
  assert_success
  assert_output 'Test User'
}

@test "canonical_name: unset -> dies" {
  git -C "${BATS_TEST_TMPDIR}" init --quiet
  # Force a clean environment so global git config doesn't leak in.
  run env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    bash -c "source '${SCRIPTS_DIR}/functions/args.bash'; \
             source '${SCRIPTS_DIR}/functions/log.bash'; \
             source '${SCRIPTS_DIR}/functions/strings.bash'; \
             source '${SCRIPTS_DIR}/functions/git.bash'; \
             git::canonical_name '${BATS_TEST_TMPDIR}'"
  assert_failure
  assert_output --partial 'user.name not set'
}

@test "canonical_name: empty -> dies" {
  git -C "${BATS_TEST_TMPDIR}" init --quiet
  git -C "${BATS_TEST_TMPDIR}" config user.name ''
  run git::canonical_name "${BATS_TEST_TMPDIR}"
  assert_failure
  assert_output --partial 'user.name is empty'
}

@test "canonical_name: dies with 0 args" {
  run git::canonical_name
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "canonical_name: dies with 2 args" {
  run git::canonical_name 'a' 'b'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- git::canonical_email ----------

@test "canonical_email: returns configured email" {
  git -C "${BATS_TEST_TMPDIR}" init --quiet
  git -C "${BATS_TEST_TMPDIR}" config user.email 'me@example.com'
  run git::canonical_email "${BATS_TEST_TMPDIR}"
  assert_success
  assert_output 'me@example.com'
}

@test "canonical_email: unset -> dies" {
  git -C "${BATS_TEST_TMPDIR}" init --quiet
  run env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    bash -c "source '${SCRIPTS_DIR}/functions/args.bash'; \
             source '${SCRIPTS_DIR}/functions/log.bash'; \
             source '${SCRIPTS_DIR}/functions/strings.bash'; \
             source '${SCRIPTS_DIR}/functions/git.bash'; \
             git::canonical_email '${BATS_TEST_TMPDIR}'"
  assert_failure
  assert_output --partial 'user.email not set'
}

@test "canonical_email: empty -> dies" {
  git -C "${BATS_TEST_TMPDIR}" init --quiet
  git -C "${BATS_TEST_TMPDIR}" config user.email ''
  run git::canonical_email "${BATS_TEST_TMPDIR}"
  assert_failure
  assert_output --partial 'user.email is empty'
}

@test "canonical_email: dies with 0 args" {
  run git::canonical_email
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "canonical_email: dies with 2 args" {
  run git::canonical_email 'a' 'b'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- git::write_distinct_identities ----------

@test "write_distinct_identities: collapses author+committer into deduped sorted union" {
  local repo
  repo="$(_seed_repo_multi_idents)"
  local out="${BATS_TEST_TMPDIR}/distinct"
  git::write_distinct_identities "${repo}" "${out}"
  local expected
  expected="$(printf 'Alice\talice@example.com\nBob\tbob@example.com\nGitHub\tnoreply@github.com\n' | LC_ALL=C sort --unique)"
  run cat "${out}"
  assert_success
  assert_output "${expected}"
}

@test "write_distinct_identities: single-identity repo -> single line" {
  local -r repo="${BATS_TEST_TMPDIR}/solo"
  git init --quiet "${repo}"
  git -C "${repo}" config commit.gpgSign false
  GIT_AUTHOR_NAME='Solo' GIT_AUTHOR_EMAIL='solo@x' \
    GIT_COMMITTER_NAME='Solo' GIT_COMMITTER_EMAIL='solo@x' \
    git -C "${repo}" commit --quiet --allow-empty --message='c1'
  local out="${BATS_TEST_TMPDIR}/distinct"
  git::write_distinct_identities "${repo}" "${out}"
  run cat "${out}"
  assert_success
  assert_output $'Solo\tsolo@x'
}

@test "write_distinct_identities: empty repo -> dies" {
  local -r repo="${BATS_TEST_TMPDIR}/empty"
  git init --quiet "${repo}"
  local out="${BATS_TEST_TMPDIR}/distinct"
  run git::write_distinct_identities "${repo}" "${out}"
  assert_failure
  assert_output --partial 'No commits found'
}

@test "write_distinct_identities: dies with 0 args" {
  run git::write_distinct_identities
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "write_distinct_identities: dies with 1 arg" {
  run git::write_distinct_identities 'a'
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "write_distinct_identities: dies with 3 args" {
  run git::write_distinct_identities 'a' 'b' 'c'
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

# ---------- git::print_identities ----------

@test "print_identities: prefix message + bullet per row to stderr" {
  local file="${BATS_TEST_TMPDIR}/idents"
  local err="${BATS_TEST_TMPDIR}/err"
  printf 'Alice\talice@x\nBob\tbob@y\n' > "${file}"
  git::print_identities 'header:' "${file}" 2> "${err}"
  run cat "${err}"
  assert_success
  assert_line --partial 'header:'
  assert_line --partial '  Alice <alice@x>'
  assert_line --partial '  Bob <bob@y>'
}

@test "print_identities: empty file -> only prefix log" {
  local file="${BATS_TEST_TMPDIR}/idents"
  local err="${BATS_TEST_TMPDIR}/err"
  : > "${file}"
  git::print_identities 'only header' "${file}" 2> "${err}"
  run cat "${err}"
  assert_success
  assert_line --partial 'only header'
  refute_line --partial '<'
}

@test "print_identities: dies with 0 args" {
  run git::print_identities
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "print_identities: dies with 1 arg" {
  run git::print_identities 'msg'
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "print_identities: dies with 3 args" {
  run git::print_identities 'a' 'b' 'c'
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

# ---------- git::prompt_select_identities ----------
# prompt::ny reads from stdin; pipe answers via heredoc-string into a bash -c
# subshell so each test gets a fresh stdin. Mirrors env_file.bats pattern.

function _run_select() {
  local -r distinct="$1"
  local -r selected="$2"
  local -r answers="$3"
  bash -c "
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/misc.bash'
    source '${SCRIPTS_DIR}/functions/prompt.bash'
    source '${SCRIPTS_DIR}/functions/git.bash'
    git::prompt_select_identities '${distinct}' '${selected}'
  " <<< "${answers}"
}

@test "prompt_select_identities: appends only y-answered rows" {
  local distinct="${BATS_TEST_TMPDIR}/distinct"
  local selected="${BATS_TEST_TMPDIR}/selected"
  printf 'Alice\talice@x\nBob\tbob@y\nGitHub\tgh@z\n' > "${distinct}"
  # answers: Alice=y, Bob=n, GitHub=y
  _run_select "${distinct}" "${selected}" $'y\nn\ny\n'
  run cat "${selected}"
  assert_success
  assert_output $'Alice\talice@x\nGitHub\tgh@z'
}

@test "prompt_select_identities: all-n -> empty selected file" {
  local distinct="${BATS_TEST_TMPDIR}/distinct"
  local selected="${BATS_TEST_TMPDIR}/selected"
  printf 'Alice\talice@x\nBob\tbob@y\n' > "${distinct}"
  _run_select "${distinct}" "${selected}" $'n\nn\n'
  [[ -f "${selected}" ]]
  [[ ! -s "${selected}" ]]
}

@test "prompt_select_identities: all-y -> selected mirrors distinct" {
  local distinct="${BATS_TEST_TMPDIR}/distinct"
  local selected="${BATS_TEST_TMPDIR}/selected"
  printf 'Alice\talice@x\nBob\tbob@y\n' > "${distinct}"
  _run_select "${distinct}" "${selected}" $'y\ny\n'
  run cat "${selected}"
  assert_success
  assert_output $'Alice\talice@x\nBob\tbob@y'
}

@test "prompt_select_identities: empty default answer -> treated as n" {
  local distinct="${BATS_TEST_TMPDIR}/distinct"
  local selected="${BATS_TEST_TMPDIR}/selected"
  printf 'Alice\talice@x\n' > "${distinct}"
  _run_select "${distinct}" "${selected}" $'\n'
  [[ -f "${selected}" ]]
  [[ ! -s "${selected}" ]]
}

@test "prompt_select_identities: truncates pre-existing selected file" {
  local distinct="${BATS_TEST_TMPDIR}/distinct"
  local selected="${BATS_TEST_TMPDIR}/selected"
  printf 'pre-existing junk\n' > "${selected}"
  printf 'Alice\talice@x\n' > "${distinct}"
  _run_select "${distinct}" "${selected}" $'n\n'
  run cat "${selected}"
  assert_success
  assert_output ''
}

@test "prompt_select_identities: empty distinct -> empty selected, no prompts" {
  local distinct="${BATS_TEST_TMPDIR}/distinct"
  local selected="${BATS_TEST_TMPDIR}/selected"
  : > "${distinct}"
  _run_select "${distinct}" "${selected}" ''
  [[ -f "${selected}" ]]
  [[ ! -s "${selected}" ]]
}

@test "prompt_select_identities: dies with 0 args" {
  run git::prompt_select_identities
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "prompt_select_identities: dies with 1 arg" {
  run git::prompt_select_identities 'a'
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "prompt_select_identities: dies with 3 args" {
  run git::prompt_select_identities 'a' 'b' 'c'
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

# ---------- git::count_author_matches ----------

@test "count_author_matches: counts commits by author tuple" {
  local repo
  repo="$(_seed_repo_multi_idents)"
  local sel="${BATS_TEST_TMPDIR}/sel"
  printf 'Alice\talice@example.com\n' > "${sel}"
  run git::count_author_matches "${repo}" "${sel}"
  assert_success
  assert_output '2'
}

@test "count_author_matches: multiple identities sum" {
  local repo
  repo="$(_seed_repo_multi_idents)"
  local sel="${BATS_TEST_TMPDIR}/sel"
  printf 'Alice\talice@example.com\nBob\tbob@example.com\n' > "${sel}"
  run git::count_author_matches "${repo}" "${sel}"
  assert_success
  assert_output '4'
}

@test "count_author_matches: zero matches" {
  local repo
  repo="$(_seed_repo_multi_idents)"
  local sel="${BATS_TEST_TMPDIR}/sel"
  printf 'Nobody\tnobody@nowhere\n' > "${sel}"
  run git::count_author_matches "${repo}" "${sel}"
  assert_success
  assert_output '0'
}

@test "count_author_matches: only matches author, not committer" {
  local repo
  repo="$(_seed_repo_multi_idents)"
  # GitHub appears only as committer (commit 2), never as author -> 0 matches.
  local sel="${BATS_TEST_TMPDIR}/sel"
  printf 'GitHub\tnoreply@github.com\n' > "${sel}"
  run git::count_author_matches "${repo}" "${sel}"
  assert_success
  assert_output '0'
}

@test "count_author_matches: dies with 0 args" {
  run git::count_author_matches
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "count_author_matches: dies with 1 arg" {
  run git::count_author_matches 'a'
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "count_author_matches: dies with 3 args" {
  run git::count_author_matches 'a' 'b' 'c'
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

# ---------- git::count_committer_matches ----------

@test "count_committer_matches: counts commits by committer tuple" {
  local repo
  repo="$(_seed_repo_multi_idents)"
  local sel="${BATS_TEST_TMPDIR}/sel"
  printf 'Alice\talice@example.com\n' > "${sel}"
  # Alice is committer of c1 and c3.
  run git::count_committer_matches "${repo}" "${sel}"
  assert_success
  assert_output '2'
}

@test "count_committer_matches: multiple identities sum" {
  local repo
  repo="$(_seed_repo_multi_idents)"
  local sel="${BATS_TEST_TMPDIR}/sel"
  printf 'Alice\talice@example.com\nGitHub\tnoreply@github.com\n' > "${sel}"
  # Alice committer x2 + GitHub committer x1 = 3
  run git::count_committer_matches "${repo}" "${sel}"
  assert_success
  assert_output '3'
}

@test "count_committer_matches: zero matches" {
  local repo
  repo="$(_seed_repo_multi_idents)"
  local sel="${BATS_TEST_TMPDIR}/sel"
  printf 'Nobody\tnobody@nowhere\n' > "${sel}"
  run git::count_committer_matches "${repo}" "${sel}"
  assert_success
  assert_output '0'
}

@test "count_committer_matches: only matches committer, not author" {
  local repo
  repo="$(_seed_repo_multi_idents)"
  # Bob is author of c3+c4 but committer only of c4. Selecting Bob counts c4 only.
  local sel="${BATS_TEST_TMPDIR}/sel"
  printf 'Bob\tbob@example.com\n' > "${sel}"
  run git::count_committer_matches "${repo}" "${sel}"
  assert_success
  assert_output '1'
}

@test "count_committer_matches: dies with 0 args" {
  run git::count_committer_matches
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "count_committer_matches: dies with 1 arg" {
  run git::count_committer_matches 'a'
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "count_committer_matches: dies with 3 args" {
  run git::count_committer_matches 'a' 'b' 'c'
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

# ---------- git::resolve_filter_repo_cmd ----------

@test "resolve_filter_repo_cmd: picks git-filter-repo when on PATH" {
  path_shim::add 'git-filter-repo' $'#!/usr/bin/env bash\nexit 0'
  local cmd=()
  git::resolve_filter_repo_cmd cmd
  [[ "${#cmd[@]}" -eq 1 ]]
  [[ "${cmd[0]}" == 'git-filter-repo' ]]
}

@test "resolve_filter_repo_cmd: falls back to nix run when only nix is available" {
  # Isolate PATH so the real git-filter-repo on the dev machine isn't picked up.
  path_shim::mkbin
  PATH="${BATS_TEST_TMPDIR}/bin:/usr/bin:/bin"
  path_shim::add 'nix' $'#!/usr/bin/env bash\nexit 0'
  local cmd=()
  run git::resolve_filter_repo_cmd cmd
  assert_success
  assert_output --partial 'falling back to: nix run'
  # Re-run outside of `run` so we can inspect the array (run executes in subshell).
  cmd=()
  git::resolve_filter_repo_cmd cmd 2> /dev/null
  [[ "${#cmd[@]}" -eq 4 ]]
  [[ "${cmd[0]}" == 'nix' ]]
  [[ "${cmd[1]}" == 'run' ]]
  [[ "${cmd[2]}" == 'github:NixOS/nixpkgs/nixpkgs-unstable#git-filter-repo' ]]
  [[ "${cmd[3]}" == '--' ]]
}

@test "resolve_filter_repo_cmd: neither tool available -> dies" {
  # Use shim dir only (no real binaries). Keep /usr/bin so BATS cleanup (rm, etc.) still works.
  path_shim::mkbin
  PATH="${BATS_TEST_TMPDIR}/bin:/usr/bin:/bin"
  local cmd=()
  # Override commands::executable_exists to only see what's in our shim dir.
  function commands::executable_exists() {
    [[ -x "${BATS_TEST_TMPDIR}/bin/$1" ]]
  }
  run git::resolve_filter_repo_cmd cmd
  assert_failure
  assert_output --partial 'Neither git-filter-repo nor nix is available'
}

@test "resolve_filter_repo_cmd: dies with 0 args" {
  run git::resolve_filter_repo_cmd
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "resolve_filter_repo_cmd: dies with 2 args" {
  run git::resolve_filter_repo_cmd 'a' 'b'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}
