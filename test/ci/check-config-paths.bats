# shellcheck disable=SC2030,SC2031 # BATS isolates each @test in its own subshell

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  load '../test_helper/git_fixture'
  CHECK="${REPO_DIR}/.ci/check-config-paths"
  # The check resolves REPO_DIR via `git rev-parse --show-toplevel`, so it must run
  # with cwd inside a git repo. It also runs every path query with `git -C
  # CONFIG_ROOT`, so the fixture has to be a real repo rather than a bare dir.
  CONFIG_ROOT="${BATS_TEST_TMPDIR}/repo"
  git_fixture::init "${CONFIG_ROOT}"
  cd "${CONFIG_ROOT}" || return 1
  # An empty EXEMPT by default: the shipped entry names lib/, which no fixture
  # configures and which would therefore read as stale.
  export EXEMPT_OVERRIDE=''
  export CONFIG_ROOT_OVERRIDE="${CONFIG_ROOT}"
  mkdir -p "${CONFIG_ROOT}/.github/workflows"
  write_sources
}

# Write all six configured sources with content that resolves. Individual tests
# overwrite whichever one they are about. Every source must exist on every run —
# a missing source is itself a failure the check reports.
write_sources() {
  write_typos 'kept/**'
  write_labeler 'kept/**'
  write_yamllint 'kept/'
  write_reviewdog './kept/*'
  write_treefmt 'kept/**'
  write_eccheck '^kept/'
  mkdir -p "${CONFIG_ROOT}/kept"
  printf 'x\n' > "${CONFIG_ROOT}/kept/file.txt"
  restage
}

write_typos() {
  printf '[files]\nextend-exclude = ["%s"]\n' "$1" > "${CONFIG_ROOT}/.typos.toml"
}

write_labeler() {
  printf 'demo:\n  - changed-files:\n      - any-glob-to-any-file:\n          - %s\n' \
    "$1" > "${CONFIG_ROOT}/.github/labeler.yml"
}

write_yamllint() {
  printf 'ignore: |\n  %s\n' "$1" > "${CONFIG_ROOT}/.yamllint.yml"
}

write_reviewdog() {
  printf 'jobs:\n  a:\n    steps:\n      - with:\n          exclude: |\n            %s\n' \
    "$1" > "${CONFIG_ROOT}/.github/workflows/ci.yml"
}

write_treefmt() {
  printf '{ pkgs }: { settings.global.excludes = [ "%s" ]; }\n' "$1" > "${CONFIG_ROOT}/.treefmt.nix"
}

# The entries here are anchored regexes rather than globs, so every case below
# spells one as it would appear in the real file, backslashes and all.
write_eccheck() {
  printf '{ "Exclude": ["%s"] }\n' "$1" > "${CONFIG_ROOT}/.editorconfig-checker.json"
}

# Re-stage after a test rewrites a source, so tracked-ness reflects the new tree.
# Staging is enough and committing is not: `git ls-files` reads the index, and the
# fixture harness pins GIT_CONFIG_GLOBAL to /dev/null, so there is no identity
# available to commit with.
restage() {
  git_fixture::run "${CONFIG_ROOT}" add -A
}

# ---------- clean tree ----------

@test "passes when every configured path is tracked" {
  run "${CHECK}"
  assert_success
}

# ---------- one failing case per source, so no source is silently unparsed ----------

@test "fails on a stale path in .typos.toml" {
  write_typos 'gone/**'
  restage
  run --separate-stderr "${CHECK}"
  assert_failure 1
  assert_stderr --partial '.typos.toml'
  assert_stderr --partial 'names gone'
}

@test "fails on a stale glob in .github/labeler.yml" {
  write_labeler 'gone/**'
  restage
  run --separate-stderr "${CHECK}"
  assert_failure 1
  assert_stderr --partial '.github/labeler.yml'
  assert_stderr --partial 'names gone'
}

@test "fails on a stale entry in .yamllint.yml" {
  write_yamllint 'gone/'
  restage
  run --separate-stderr "${CHECK}"
  assert_failure 1
  assert_stderr --partial '.yamllint.yml'
  assert_stderr --partial 'names gone'
}

@test "fails on a stale reviewdog exclude in a workflow" {
  write_reviewdog './gone/*'
  restage
  run --separate-stderr "${CHECK}"
  assert_failure 1
  assert_stderr --partial '.github/workflows/ci.yml'
  assert_stderr --partial 'names gone'
}

@test "fails on a stale exclude in .treefmt.nix" {
  write_treefmt 'gone/**'
  restage
  run --separate-stderr "${CHECK}"
  assert_failure 1
  assert_stderr --partial '.treefmt.nix'
  assert_stderr --partial 'names gone'
}

@test "fails on a stale entry in .editorconfig-checker.json" {
  write_eccheck '^gone/'
  restage
  run --separate-stderr "${CHECK}"
  assert_failure 1
  assert_stderr --partial '.editorconfig-checker.json'
  assert_stderr --partial 'names gone'
}

# ---------- the regex grammar of .editorconfig-checker.json ----------

@test "regex anchors are stripped before resolving" {
  # ^LICENSE$ pins one exact file. Left in place, neither anchor is a path
  # character and the entry resolves to nothing.
  printf 'x\n' > "${CONFIG_ROOT}/LICENSE"
  write_eccheck '^LICENSE$'
  restage
  run "${CHECK}"
  assert_success
}

@test "an escaped dot resolves as a literal dot" {
  mkdir -p "${CONFIG_ROOT}/.dotted"
  printf 'x\n' > "${CONFIG_ROOT}/.dotted/f.txt"
  write_eccheck '^\\.dotted/'
  restage
  run "${CHECK}"
  assert_success
}

@test "an entry is truncated at the first unescaped metacharacter" {
  # Everything from `(` on is alternation, not path text, so the entry pins
  # kept/ and nothing more.
  write_eccheck '^kept/(a|b)'
  restage
  run "${CHECK}"
  assert_success
}

@test "a quantifier drops the incomplete component it quantifies" {
  # `*` quantifies the preceding atom, so `kept/gone*` matches kept/gon,
  # kept/gone, kept/gonee — it pins no component past kept/. Truncating at the
  # metacharacter alone would resolve kept/gone and fail on a live entry.
  write_eccheck '^kept/gone*'
  restage
  run "${CHECK}"
  assert_success
}

@test "a regex entry with no literal prefix is skipped" {
  write_eccheck '^.*\\.md$'
  restage
  run "${CHECK}"
  assert_success
}

# ---------- what counts as "git knows about it" ----------

@test "a gitignored directory passes even when absent from the working tree" {
  # The whole point of querying git rather than the filesystem: generated output
  # is configured deliberately and is missing from a fresh checkout.
  printf 'generated/\n' > "${CONFIG_ROOT}/.gitignore"
  write_typos 'generated/**'
  restage
  [[ ! -e "${CONFIG_ROOT}/generated" ]]
  run "${CHECK}"
  assert_success
}

@test "a tracked file, not just a directory, passes" {
  write_typos 'kept/file.txt'
  restage
  run "${CHECK}"
  assert_success
}

@test "an untracked, unignored directory fails even though it is on disk" {
  # The mirror of the case above: present locally, absent for everyone else.
  mkdir -p "${CONFIG_ROOT}/local-only"
  printf 'x\n' > "${CONFIG_ROOT}/local-only/f.txt"
  write_typos 'local-only/**'
  run --separate-stderr "${CHECK}"
  assert_failure 1
  assert_stderr --partial 'names local-only'
}

@test "an entry with no literal prefix is skipped" {
  write_typos '**/*.md'
  restage
  run "${CHECK}"
  assert_success
}

@test "a leading ./ and a trailing slash are stripped before resolving" {
  write_reviewdog './kept/'
  restage
  run "${CHECK}"
  assert_success
}

# ---------- missing and unparsable sources fail loudly ----------

@test "fails when a configured source is missing entirely" {
  rm -f "${CONFIG_ROOT}/.yamllint.yml"
  run --separate-stderr "${CHECK}"
  assert_failure 1
  assert_stderr --partial '.yamllint.yml: configured source is missing'
}

@test "fails loudly when .editorconfig-checker.json cannot be parsed" {
  printf '{ "Exclude": [ \n' > "${CONFIG_ROOT}/.editorconfig-checker.json"
  restage
  run "${CHECK}"
  assert_failure
  refute_output --partial 'audit passed'
}

@test "fails loudly when a source cannot be parsed, rather than reading it as empty" {
  # A parser failure must not look like "this source configures no paths".
  printf 'this: is: not: valid: yaml:\n  - [\n' > "${CONFIG_ROOT}/.github/labeler.yml"
  restage
  run "${CHECK}"
  assert_failure
  refute_output --partial 'audit passed'
}

# ---------- EXEMPT, both staleness directions ----------

@test "an exempt path is allowed to resolve nowhere" {
  export EXEMPT_OVERRIDE='vendored'
  write_typos 'vendored/**'
  restage
  run "${CHECK}"
  assert_success
}

@test "fails when an EXEMPT entry is configured nowhere" {
  export EXEMPT_OVERRIDE='never-mentioned'
  run --separate-stderr "${CHECK}"
  assert_failure 1
  assert_stderr --partial 'stale EXEMPT entry: never-mentioned'
}

@test "fails when an EXEMPT entry names a path that resolves on its own" {
  # The exemption is unnecessary, so it must be removed rather than left to rot.
  export EXEMPT_OVERRIDE='kept'
  run --separate-stderr "${CHECK}"
  assert_failure 1
  assert_stderr --partial 'stale EXEMPT entry: kept'
}

# ---------- arity ----------

@test "dies when given any argument" {
  run "${CHECK}" extra
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "--help exits 0" {
  run "${CHECK}" --help
  assert_success
  assert_output --partial 'configured'
}
