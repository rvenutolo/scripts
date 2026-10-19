setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091 # paths resolved at runtime via SCRIPTS_DIR
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091 # paths resolved at runtime via SCRIPTS_DIR
  source "${SCRIPTS_DIR}/functions/log.bash"
  load '../test_helper/git_fixture'
  SCRIPT="${REPO_DIR}/.ci/plan-test-shards"
  # The planner resolves its repo root via `git rev-parse --show-toplevel`, and
  # every root and output path is relative to it, so it runs inside a fixture repo.
  FIXTURE_REPO="${BATS_TEST_TMPDIR}/repo"
  git_fixture::init "${FIXTURE_REPO}"
  FIXTURE_REPO="$(cd "${FIXTURE_REPO}" && pwd -P)"
  cd "${FIXTURE_REPO}" || return 1
  WEIGHTS="${BATS_TEST_TMPDIR}/weights.tsv"
  printf '# no weighted files\n' > "${WEIGHTS}"
  export TEST_SHARD_WEIGHTS_OVERRIDE="${WEIGHTS}"
}

# Write a fixture .bats file at repo-relative path $1 holding $2 tests. The test
# keyword is assembled at runtime so BATS does not parse these lines as tests of
# this file.
write_bats() {
  local -r path="$1"
  local -r count="$2"
  local -r keyword='@''test'
  mkdir --parents "${FIXTURE_REPO}/$(dirname "${path}")"
  : > "${FIXTURE_REPO}/${path}"
  local i
  for ((i = 0; i < count; i++)); do
    printf '%s "t%s" {\n  true\n}\n' "${keyword}" "${i}" >> "${FIXTURE_REPO}/${path}"
  done
}

# Seven files of varied size across two roots, one of them nested.
write_seven() {
  write_bats 'suite/a/one.bats' 9
  write_bats 'suite/a/two.bats' 7
  write_bats 'suite/a/nested/three.bats' 5
  write_bats 'suite/b/four.bats' 4
  write_bats 'suite/b/five.bats' 3
  write_bats 'suite/b/six.bats' 2
  write_bats 'suite/b/seven.bats' 1
}

@test "the shards of a count partition the file list" {
  write_seven
  local shard all="${BATS_TEST_TMPDIR}/all.txt"
  : > "${all}"
  for shard in 0 1 2; do
    run "${SCRIPT}" 3 "${shard}" suite/a suite/b
    assert_success
    printf '%s\n' "${output}" >> "${all}"
  done
  run sort "${all}"
  assert_output "$(printf '%s\n' suite/a/nested/three.bats suite/a/one.bats suite/a/two.bats \
    suite/b/five.bats suite/b/four.bats suite/b/seven.bats suite/b/six.bats)"
  run sort --unique "${all}"
  local -r unique_count="$(printf '%s\n' "${output}" | wc --lines)"
  ((unique_count == 7))
}

@test "every shard is non-empty and sorted" {
  write_seven
  local shard
  for shard in 0 1 2; do
    run "${SCRIPT}" 3 "${shard}" suite/a suite/b
    assert_success
    refute_output ''
    assert_output "$(printf '%s\n' "${output}" | sort)"
  done
}

@test "the partition is deterministic" {
  write_seven
  run "${SCRIPT}" 3 1 suite/a suite/b
  local -r first="${output}"
  run "${SCRIPT}" 3 1 suite/a suite/b
  assert_output "${first}"
}

@test "a weighted file is placed alone when it outweighs the rest" {
  write_seven
  printf 'suite/b/seven.bats\t100000\n' > "${WEIGHTS}"
  run "${SCRIPT}" 2 0 suite/a suite/b
  assert_success
  assert_output 'suite/b/seven.bats'
}

@test "unlisted files are weighted by their test count" {
  write_bats 'suite/big.bats' 10
  write_bats 'suite/small.bats' 1
  write_bats 'suite/mid1.bats' 5
  write_bats 'suite/mid2.bats' 5
  run "${SCRIPT}" 2 0 suite
  assert_success
  assert_output "$(printf '%s\n' suite/big.bats suite/small.bats)"
  run "${SCRIPT}" 2 1 suite
  assert_output "$(printf '%s\n' suite/mid1.bats suite/mid2.bats)"
}

@test "a weights entry for a file outside the scan is ignored" {
  write_seven
  printf '# comment\n\nsuite/gone.bats\t5000\n' > "${WEIGHTS}"
  run "${SCRIPT}" 1 0 suite/a suite/b
  assert_success
  refute_output --partial 'gone'
  local -r count="$(printf '%s\n' "${output}" | wc --lines)"
  ((count == 7))
}

@test "with no roots it reads .ci/test-suites" {
  write_seven
  mkdir --parents "${FIXTURE_REPO}/.ci"
  printf '# roots\n\nsuite/b\n' > "${FIXTURE_REPO}/.ci/test-suites"
  run "${SCRIPT}" 1 0
  assert_success
  assert_output "$(printf '%s\n' suite/b/five.bats suite/b/four.bats suite/b/seven.bats suite/b/six.bats)"
}

@test "the default weights file is .ci/test-shard-weights" {
  write_seven
  unset TEST_SHARD_WEIGHTS_OVERRIDE
  mkdir --parents "${FIXTURE_REPO}/.ci"
  printf 'suite/b/seven.bats\t100000\n' > "${FIXTURE_REPO}/.ci/test-shard-weights"
  run "${SCRIPT}" 2 0 suite/a suite/b
  assert_success
  assert_output 'suite/b/seven.bats'
}

@test "the real tree partitions cleanly" {
  cd "${REPO_DIR}" || return 1
  unset TEST_SHARD_WEIGHTS_OVERRIDE
  local shard all="${BATS_TEST_TMPDIR}/all.txt" expected="${BATS_TEST_TMPDIR}/expected.txt"
  : > "${all}"
  for shard in 0 1 2 3; do
    run "${SCRIPT}" 4 "${shard}"
    assert_success
    printf '%s\n' "${output}" >> "${all}"
  done
  local root
  : > "${expected}"
  while IFS= read -r root; do
    if [[ -z "${root}" || "${root}" == '#'* ]]; then
      continue
    fi
    find "${root}" -type f -name '*.bats' >> "${expected}"
  done < "${REPO_DIR}/.ci/test-suites"
  run sort "${all}"
  assert_output "$(sort "${expected}")"
}

@test "dies when count is zero" {
  write_seven
  run "${SCRIPT}" 0 0 suite/a
  assert_failure 1
  assert_output --partial "count must be an integer of at least 1: 0"
}

@test "dies when count is not an integer" {
  write_seven
  run "${SCRIPT}" x 0 suite/a
  assert_failure 1
  assert_output --partial "count must be an integer of at least 1: x"
}

@test "dies when index equals count" {
  write_seven
  run "${SCRIPT}" 3 3 suite/a
  assert_failure 1
  assert_output --partial "index must be an integer from 0 to 2: 3"
}

@test "dies when index is negative" {
  write_seven
  run "${SCRIPT}" 3 -1 suite/a
  assert_failure 1
  assert_output --partial "index must be an integer from 0 to 2: -1"
}

@test "dies when a root is missing" {
  write_seven
  run "${SCRIPT}" 1 0 suite/a suite/nope
  assert_failure 1
  assert_output --partial 'suite/nope'
}

@test "dies when the roots hold no .bats files" {
  mkdir --parents "${FIXTURE_REPO}/empty"
  run "${SCRIPT}" 1 0 empty
  assert_failure 1
  assert_output --partial 'no .bats files'
}

@test "dies when count exceeds the number of files" {
  write_bats 'suite/only.bats' 1
  write_bats 'suite/pair.bats' 1
  run "${SCRIPT}" 3 0 suite
  assert_failure 1
  assert_output --partial 'count 3 exceeds the 2 test files'
}

@test "dies when the weights file is missing" {
  write_seven
  export TEST_SHARD_WEIGHTS_OVERRIDE="${BATS_TEST_TMPDIR}/absent.tsv"
  run "${SCRIPT}" 1 0 suite/a
  assert_failure 1
  assert_output --partial 'absent.tsv'
}

@test "dies when given no arguments" {
  run "${SCRIPT}"
  assert_failure
  assert_output --partial 'Expected at least 2 arguments'
}

@test "dies when given one argument" {
  run "${SCRIPT}" 1
  assert_failure
  assert_output --partial 'Expected at least 2 arguments'
}

@test "--help prints the description" {
  run "${SCRIPT}" --help
  assert_success
  assert_output --partial 'shard'
}
