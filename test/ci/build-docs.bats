setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091 # path resolved at runtime via SCRIPTS_DIR
  source "${SCRIPTS_DIR}/functions/args.bash"
  load '../test_helper/git_fixture'
  load '../test_helper/path_shim'
  CHECK="${REPO_DIR}/.ci/build-docs"
  # Redirect generated docs to a per-test tmpdir so the suite never mutates the
  # real .docs/ and parallel runs of this file don't race on shared output.
  export DOCS_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/docs"
}

# .ci/build-docs derives its own repo root via `git rev-parse --show-toplevel`.
# common.bash's fixture-escape hardening leaves CWD at BATS_TEST_TMPDIR
# (outside any git repo) by design, so cd into REPO_DIR before every invocation
# — this test targets the real repo.
run_check() {
  cd "${REPO_DIR}" || return 1
  run "$@"
}

# page_count <dir> — generated per-file pages in a docs dir, excluding its index.
page_count() {
  find "$1" -maxdepth 1 -type f -name '*.md' ! -name 'index.md' | wc --lines
}

# index_link_count <dir> — bullet links the dir's index.md carries.
index_link_count() {
  grep --count '^- \[' "$1/index.md"
}

@test "clean run exits 0" {
  run_check "${CHECK}"
  assert_success
}

@test "--help exits 0 and prints help text" {
  run_check "${CHECK}" --help
  assert_success
  assert_output --partial 'build-docs'
}

@test "dies when given an argument" {
  run_check "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "populates the functions docs dir with at least one markdown page" {
  run_check "${CHECK}"
  assert_success
  run find "${DOCS_DIR_OVERRIDE}/functions" -maxdepth 1 -type f -name '*.md'
  assert_success
  assert_output --partial '.md'
}

@test "populates the scripts docs dir with at least one markdown page" {
  run_check "${CHECK}"
  assert_success
  run find "${DOCS_DIR_OVERRIDE}/scripts" -type f -name '*.md'
  assert_success
  assert_output --partial '.md'
}

@test "documents the repo it runs in, not SCRIPTS_DIR" {
  # A decoy SCRIPTS_DIR that can satisfy sourcing but holds no script dirs. If
  # build-docs rooted its input scan at SCRIPTS_DIR it would find nothing to
  # document; it must root at the repo it was invoked in instead.
  local decoy="${BATS_TEST_TMPDIR}/decoy"
  mkdir -p "${decoy}/functions"
  ln --symbolic "${SCRIPTS_DIR}/.functions.bash" "${decoy}/.functions.bash"
  local lib
  for lib in "${SCRIPTS_DIR}"/functions/*.bash; do
    ln --symbolic "${lib}" "${decoy}/functions/$(basename -- "${lib}")"
  done
  cd "${REPO_DIR}" || return 1
  SCRIPTS_DIR="${decoy}" run "${CHECK}"
  assert_success
  run find "${DOCS_DIR_OVERRIDE}/scripts/non-interactive" -type f -name 'new-script.md'
  assert_success
  assert_output --partial 'new-script.md'
}

@test "every generated functions page is linked from the functions index" {
  # write_index enumerates the directory it just filled, so a page that exists
  # but is unlinked (or a link to a page that was never written) means the index
  # and the generator disagree about what was built.
  run_check "${CHECK}"
  assert_success
  local -r dir="${DOCS_DIR_OVERRIDE}/functions"
  [ "$(page_count "${dir}")" -eq "$(index_link_count "${dir}")" ]
  [ "$(page_count "${dir}")" -ge 40 ]
}

@test "every generated script page is linked from its per-directory index" {
  run_check "${CHECK}"
  assert_success
  local -r dir="${DOCS_DIR_OVERRIDE}/scripts/non-interactive"
  [ "$(page_count "${dir}")" -eq "$(index_link_count "${dir}")" ]
  [ "$(page_count "${dir}")" -ge 100 ]
}

@test "the top-level scripts index links every per-directory index that exists" {
  run_check "${CHECK}"
  assert_success
  local -r top="${DOCS_DIR_OVERRIDE}/scripts/index.md"
  local subdir
  for subdir in non-interactive interactive install set_up misc root; do
    run grep --fixed-strings "(${subdir}/index.md)" "${top}"
    assert_success
  done
}

@test "a script page renders its file-level shdoc header, not just its name" {
  # render_script_header exists because shdoc drops every file-level tag except
  # @description. These four sections are the gap it fills.
  run_check "${CHECK}"
  assert_success
  run cat "${DOCS_DIR_OVERRIDE}/scripts/non-interactive/new-script.md"
  assert_success
  assert_output --partial '# new-script'
  assert_output --partial '## Overview'
  assert_output --partial '## Arguments'
  assert_output --partial '## Exit codes'
  # @arg $@ files -> a bulleted, name-annotated entry.
  # shellcheck disable=SC2016 # $@ is literal text in the rendered markdown, not an expansion
  assert_output --partial '- **$@** (`files`)'
  # @exitcode 1 ... -> a bulleted, number-annotated entry.
  assert_output --partial '- **1**:'
}

@test "a @noargs script renders an explicit empty Arguments section" {
  # The @noargs arm of render_script_header. Silence would be indistinguishable
  # from a header the renderer failed to parse.
  run_check "${CHECK}"
  assert_success
  run cat "${DOCS_DIR_OVERRIDE}/scripts/root/run-all-checks.md"
  assert_success
  assert_output --partial '## Arguments'
  assert_output --partial 'None.'
}

@test "a functions page carries its per-function shdoc docs" {
  # The functions arm runs shdoc directly (no header renderer), so the evidence
  # that it worked is the presence of the library's own function entries.
  run_check "${CHECK}"
  assert_success
  run cat "${DOCS_DIR_OVERRIDE}/functions/strings.md"
  assert_success
  assert_output --partial 'strings::is_empty'
}

@test "the home page is a copy of README.md" {
  run_check "${CHECK}"
  assert_success
  run cmp --silent "${DOCS_DIR_OVERRIDE}/index.md" "${REPO_DIR}/README.md"
  assert_success
}

@test "a rebuild wipes pages left over from the previous build" {
  # reset_output_dirs. Without it a renamed or deleted script keeps a stale page
  # on the published site forever, and nothing else in the pipeline notices.
  run_check "${CHECK}"
  assert_success
  local -r stale="${DOCS_DIR_OVERRIDE}/functions/no-such-topic.md"
  printf '%s\n' '# leftover from an earlier build' > "${stale}"

  run_check "${CHECK}"
  assert_success

  run test -e "${stale}"
  assert_failure
}

@test "no generated page is empty" {
  # An empty page means shdoc or the header renderer produced nothing for a real
  # input file — a silent per-file failure the exit code does not surface.
  run_check "${CHECK}"
  assert_success
  run find "${DOCS_DIR_OVERRIDE}" -type f -name '*.md' -empty
  assert_success
  refute_output
}

# SHDOC is derived from the repo root, so a clone that skipped
# `git submodule update --init` has no .shdoc/ and the generator would otherwise fail
# somewhere deep in an awk pipeline. The guard names the recovery command, and a
# fixture repo is the only way to reach it without breaking the real checkout.
@test "dies with the submodule hint when shdoc is absent" {
  local -r fixture="${BATS_TEST_TMPDIR}/norepo"
  git_fixture::init "${fixture}"
  cd "${fixture}" || return 1
  run "${CHECK}"
  assert_failure 1
  assert_output --partial 'shdoc not found'
  assert_output --partial 'git submodule update'
}

# gawk, not awk: the shdoc pipeline uses gawk-only constructs, so a machine carrying
# only mawk or busybox awk must be told which one is missing rather than failing on a
# syntax error inside a program body. Only bash and git are linked into the fixture
# PATH — all the script touches before this guard.
@test "dies when gawk is not on PATH" {
  local -r bin_dir="${BATS_TEST_TMPDIR}/nogawk"
  mkdir --parents "${bin_dir}"
  # bash for the `#!/usr/bin/env bash` shebang, git for the repo-root resolution at
  # the top of the script. Nothing else runs before the guard under test.
  ln --symbolic "$(command -v bash)" "${bin_dir}/bash"
  ln --symbolic "$(command -v git)" "${bin_dir}/git"
  cd "${REPO_DIR}" || return 1
  PATH="${bin_dir}" BASH_ENV="${SAFE_BASH_ENV}" run "${CHECK}"
  assert_failure 1
  assert_output --partial 'gawk not found'
}
