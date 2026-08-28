setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  load '../test_helper/cli_shim'
  CHECK="${REPO_DIR}/.ci/build-site"
  # Redirect the generated markdown to a per-test tmpdir: the real .docs/ is
  # shared mutable state that .ci/build-docs wipes on every run, so an
  # unredirected test would race any parallel test reading it.
  export DOCS_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/docs"
  # mkdocs is stubbed in every test. Rendering the site for real would write the
  # repo's site/ from a fixture docs tree, and the real --strict build is
  # exercised on every run of the lint suite and of CI's lint job anyway.
  cli_shim::record mkdocs
}

# .ci/build-site derives its own repo root via `git rev-parse --show-toplevel`.
# common.bash's fixture-escape hardening leaves CWD at BATS_TEST_TMPDIR (outside
# any git repo) by design, so cd into REPO_DIR before every invocation — this
# test targets the real repo.
run_check() {
  cd "${REPO_DIR}" || return 1
  run "$@"
}

@test "clean run exits 0" {
  run_check "${CHECK}"
  assert_success
}

@test "generates the markdown reference before rendering" {
  run_check "${CHECK}"
  assert_success
  run test -f "${DOCS_DIR_OVERRIDE}/functions/index.md"
  assert_success
  run test -f "${DOCS_DIR_OVERRIDE}/scripts/index.md"
  assert_success
  run test -f "${DOCS_DIR_OVERRIDE}/index.md"
  assert_success
}

@test "invokes mkdocs with --strict and the repo's config" {
  run_check "${CHECK}"
  assert_success
  run cli_shim::calls mkdocs
  assert_output 'build --strict --config-file .mkdocs.yml'
}

@test "invokes mkdocs exactly once" {
  run_check "${CHECK}"
  assert_success
  run cli_shim::call_count mkdocs
  assert_output '1'
}

@test "fails when mkdocs rejects the site" {
  # --strict turns a mkdocs warning into a non-zero exit; that status is the
  # whole reason this script is gated, so it must reach the caller.
  cli_shim::record_with_output mkdocs '' 1
  run_check "${CHECK}"
  assert_failure
}

@test "fails when doc generation fails" {
  # An unwritable output base makes .ci/build-docs fail; the site must not be
  # rendered from a stale docs tree, and the failure must reach the caller.
  export DOCS_DIR_OVERRIDE='/proc/nonexistent/docs'
  run_check "${CHECK}"
  assert_failure
  run cli_shim::call_count mkdocs
  assert_output '0'
}

# Only bash is linked into the fixture PATH: the mkdocs guard runs before the
# script touches git or anything else, so nothing but the shebang needs to
# resolve. Clearing BASH_ENV is what keeps the child bash from re-sourcing the
# ambient ~/.bashrc and putting the real mkdocs back on PATH.
@test "dies when mkdocs is not on PATH" {
  local -r bin_dir="${BATS_TEST_TMPDIR}/nomkdocs"
  mkdir --parents "${bin_dir}"
  ln --symbolic "$(command -v bash)" "${bin_dir}/bash"
  cd "${REPO_DIR}" || return 1
  PATH="${bin_dir}" BASH_ENV="${SAFE_BASH_ENV}" run "${CHECK}"
  assert_failure 1
  assert_output --partial 'mkdocs'
}

@test "rejects an unexpected argument" {
  run_check "${CHECK}" unexpected
  assert_failure 1
  assert_output --partial 'Expected no arguments'
}

@test "--help exits 0 and prints the description" {
  run_check "${CHECK}" --help
  assert_success
  assert_output --partial 'build-site'
  assert_output --partial 'mkdocs'
}

@test "--help does not build anything" {
  run_check "${CHECK}" --help
  assert_success
  run cli_shim::call_count mkdocs
  assert_output '0'
}
