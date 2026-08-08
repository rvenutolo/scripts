setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-links-allowed-endpoints"
  ROOT="${BATS_TEST_TMPDIR}/root"
  mkdir -p "${ROOT}"
  LYCHEERC="${BATS_TEST_TMPDIR}/lycheerc"
  LINKS_WF="${BATS_TEST_TMPDIR}/links.yml"
  printf 'exclude_path = [\n  ".git",\n  "vendor",\n]\n' > "${LYCHEERC}"
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

run_check() {
  LINKS_WORKFLOW_OVERRIDE="${LINKS_WF}" \
    LYCHEERC_OVERRIDE="${LYCHEERC}" \
    MARKDOWN_ROOT_OVERRIDE="${ROOT}" \
    run "${CHECK}"
}

@test "passes when every markdown host is in the allowlist" {
  printf 'See [docs](https://example.com/page).\n' > "${ROOT}/a.md"
  write_allowlist 'example.com'
  run_check
  assert_success
}

@test "fails when a markdown link introduces an unlisted host" {
  printf 'See [docs](https://example.com/page) and [more](https://other.test/x).\n' > "${ROOT}/a.md"
  write_allowlist 'example.com'
  run_check
  assert_failure
  assert_output --partial 'other.test'
}

@test "passes when the allowlist has extra hosts with no link (redirect targets)" {
  printf 'See [docs](https://example.com/page).\n' > "${ROOT}/a.md"
  write_allowlist 'example.com' 'cdn.example.net'
  run_check
  assert_success
}

@test "ignores hosts that appear only in an excluded path" {
  mkdir -p "${ROOT}/vendor"
  printf 'See [x](https://excluded.test/y).\n' > "${ROOT}/vendor/b.md"
  printf 'See [docs](https://example.com/page).\n' > "${ROOT}/a.md"
  write_allowlist 'example.com'
  run_check
  assert_success
}

@test "ignores URLs inside fenced code blocks" {
  {
    printf 'Prose link: [docs](https://example.com/page).\n\n'
    printf '```\ncurl https://fenced.test/thing\n```\n'
  } > "${ROOT}/a.md"
  write_allowlist 'example.com'
  run_check
  assert_success
}

@test "ignores relative and anchor-only links" {
  printf 'See [rel](./other.md) and [anchor](#section).\n' > "${ROOT}/a.md"
  write_allowlist 'example.com'
  run_check
  assert_success
}

@test "passes when no markdown file has an external link" {
  printf 'Just prose.\n' > "${ROOT}/a.md"
  write_allowlist 'example.com'
  run_check
  assert_success
}

@test "strips a trailing period from a bare host link" {
  printf 'Visit https://example.com.\n' > "${ROOT}/a.md"
  write_allowlist 'example.com'
  run_check
  assert_success
}

@test "reports every missing host, not just the first" {
  printf '[a](https://one.test/x) [b](https://two.test/y)\n' > "${ROOT}/a.md"
  write_allowlist 'example.com'
  run_check
  assert_failure
  assert_output --partial 'one.test'
  assert_output --partial 'two.test'
}

@test "dies when the links workflow is missing" {
  printf 'Just prose.\n' > "${ROOT}/a.md"
  LINKS_WORKFLOW_OVERRIDE="${BATS_TEST_TMPDIR}/absent.yml" \
    LYCHEERC_OVERRIDE="${LYCHEERC}" \
    MARKDOWN_ROOT_OVERRIDE="${ROOT}" \
    run "${CHECK}"
  assert_failure
}

@test "dies when given an argument" {
  printf 'Just prose.\n' > "${ROOT}/a.md"
  write_allowlist 'example.com'
  LINKS_WORKFLOW_OVERRIDE="${LINKS_WF}" \
    LYCHEERC_OVERRIDE="${LYCHEERC}" \
    MARKDOWN_ROOT_OVERRIDE="${ROOT}" \
    run "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}
