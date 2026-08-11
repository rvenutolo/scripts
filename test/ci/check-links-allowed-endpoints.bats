setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  load '../test_helper/git_fixture'
  CHECK="${REPO_DIR}/.ci/check-links-allowed-endpoints"
  ROOT="${BATS_TEST_TMPDIR}/root"
  mkdir -p "${ROOT}"
  # The check enumerates markdown with git ls-files, so the fixture root has to
  # be a real work tree. Identity is set locally so the fixture repo works even
  # when the environment has no global git config.
  git_fixture::init "${ROOT}" --initial-branch=main
  git_fixture::run "${ROOT}" config user.email 'bats@example.com'
  git_fixture::run "${ROOT}" config user.name 'BATS Fixture'
  # The developer's global gitignore would otherwise leak into the fixture repo
  # and silently ignore fixture paths such as "vendor".
  git_fixture::run "${ROOT}" config core.excludesFile '/dev/null'
  LYCHEERC="${BATS_TEST_TMPDIR}/lycheerc"
  LINKS_WF="${BATS_TEST_TMPDIR}/links.yml"
  printf 'exclude_path = [\n  ".git",\n  "vendor",\n]\n' > "${LYCHEERC}"
}

# track <path...> — stage the given root-relative fixture paths so git ls-files
# reports them. Staging is enough; no commit is needed.
track() {
  git_fixture::run "${ROOT}" add -- "$@"
}

# write_allowlist <host...> — a links.yml whose harden-runner step allows the
# given hosts, each on port 443.
write_allowlist() {
  {
    printf 'jobs:\n  lychee:\n    steps:\n'
    printf '      - uses: step-security/harden-runner@ab7a9404c0f3da075243ca237b5fac12c98deaa5\n'
    printf '        with:\n          egress-policy: block\n          allowed-endpoints: >-\n'
    local host
    for host in "$@"; do
      printf '            %s:443\n' "${host}"
    done
  } > "${LINKS_WF}"
}

# .ci/check-links-allowed-endpoints derives its own repo root via
# `git rev-parse --show-toplevel`. common.bash's #248 hardening leaves CWD at
# BATS_TEST_TMPDIR (outside any git repo) by design, so cd into REPO_DIR before
# every invocation — this test targets the real repo.
run_check() {
  cd "${REPO_DIR}" || return 1
  LINKS_WORKFLOW_OVERRIDE="${LINKS_WF}" \
    LYCHEERC_OVERRIDE="${LYCHEERC}" \
    MARKDOWN_ROOT_OVERRIDE="${ROOT}" \
    run "${CHECK}"
}

@test "passes when every markdown host is in the allowlist" {
  printf 'See [docs](https://example.com/page).\n' > "${ROOT}/a.md"
  track 'a.md'
  write_allowlist 'example.com'
  run_check
  assert_success
}

@test "fails when a markdown link introduces an unlisted host" {
  printf 'See [docs](https://example.com/page) and [more](https://other.test/x).\n' > "${ROOT}/a.md"
  track 'a.md'
  write_allowlist 'example.com'
  run_check
  assert_failure
  assert_output --partial 'other.test'
}

@test "passes when the allowlist has extra hosts with no link (redirect targets)" {
  printf 'See [docs](https://example.com/page).\n' > "${ROOT}/a.md"
  track 'a.md'
  write_allowlist 'example.com' 'cdn.example.net'
  run_check
  assert_success
}

@test "ignores hosts that appear only in an excluded path" {
  mkdir -p "${ROOT}/vendor"
  printf 'See [x](https://excluded.test/y).\n' > "${ROOT}/vendor/b.md"
  printf 'See [docs](https://example.com/page).\n' > "${ROOT}/a.md"
  track 'a.md' 'vendor/b.md'
  write_allowlist 'example.com'
  run_check
  assert_success
}

@test "ignores hosts in an untracked markdown file" {
  printf 'See [docs](https://example.com/page).\n' > "${ROOT}/a.md"
  track 'a.md'
  # Never staged: CI checks out tracked files only, so lychee never sees this.
  printf 'Local note: [scratch](https://untracked.test/x).\n' > "${ROOT}/untracked.md"
  write_allowlist 'example.com'
  run_check
  assert_success
  refute_output --partial 'untracked.test'
}

@test "ignores hosts in a gitignored markdown file" {
  printf 'See [docs](https://example.com/page).\n' > "${ROOT}/a.md"
  track 'a.md'
  printf 'ignored.md\n' > "${ROOT}/.gitignore"
  printf 'Local plan: [x](https://ignored.test/y).\n' > "${ROOT}/ignored.md"
  write_allowlist 'example.com'
  run_check
  assert_success
  refute_output --partial 'ignored.test'
}

@test "ignores URLs inside fenced code blocks" {
  {
    printf 'Prose link: [docs](https://example.com/page).\n\n'
    printf '```\ncurl https://fenced.test/thing\n```\n'
  } > "${ROOT}/a.md"
  track 'a.md'
  write_allowlist 'example.com'
  run_check
  assert_success
}

@test "ignores relative and anchor-only links" {
  printf 'See [rel](./other.md) and [anchor](#section).\n' > "${ROOT}/a.md"
  track 'a.md'
  write_allowlist 'example.com'
  run_check
  assert_success
}

@test "passes when no markdown file has an external link" {
  printf 'Just prose.\n' > "${ROOT}/a.md"
  track 'a.md'
  write_allowlist 'example.com'
  run_check
  assert_success
}

@test "strips a trailing period from a bare host link" {
  printf 'Visit https://example.com.\n' > "${ROOT}/a.md"
  track 'a.md'
  write_allowlist 'example.com'
  run_check
  assert_success
}

@test "reports every missing host, not just the first" {
  printf '[a](https://one.test/x) [b](https://two.test/y)\n' > "${ROOT}/a.md"
  track 'a.md'
  write_allowlist 'example.com'
  run_check
  assert_failure
  assert_output --partial 'one.test'
  assert_output --partial 'two.test'
}

@test "dies when the links workflow is missing" {
  printf 'Just prose.\n' > "${ROOT}/a.md"
  track 'a.md'
  cd "${REPO_DIR}"
  LINKS_WORKFLOW_OVERRIDE="${BATS_TEST_TMPDIR}/absent.yml" \
    LYCHEERC_OVERRIDE="${LYCHEERC}" \
    MARKDOWN_ROOT_OVERRIDE="${ROOT}" \
    run "${CHECK}"
  assert_failure
}

@test "dies when given an argument" {
  printf 'Just prose.\n' > "${ROOT}/a.md"
  track 'a.md'
  write_allowlist 'example.com'
  LINKS_WORKFLOW_OVERRIDE="${LINKS_WF}" \
    LYCHEERC_OVERRIDE="${LYCHEERC}" \
    MARKDOWN_ROOT_OVERRIDE="${ROOT}" \
    run "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}
