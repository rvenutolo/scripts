setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  load '../test_helper/cli_shim'
  CHECK="${REPO_DIR}/.ci/report-coverage-drop"
  export GH_REPO='someone/somewhere'
  SHA='0123456789abcdef0123456789abcdef01234567'
  URL='https://app.codecov.io/gh/someone/somewhere/commit/0123456789abcdef'
  DESC='60.00% (-2.50%) compared to fedcba9'
}

# BASH_ENV is neutralized on every invocation: the script's own `#!/usr/bin/env bash`
# startup would re-source ~/.bashrc, which re-prepends the real nix PATH and would
# shadow the gh shim with the REAL gh. This script files issues on a live repo, so an
# unshimmed invocation is not a failed test — it is an unintended write. SAFE_BASH_ENV
# keeps kcov's trace helper and nothing else; the poison-gh test below proves it.
run_check() {
  BASH_ENV="${SAFE_BASH_ENV}" run "$@"
}

# report <context> <state> — run the script with the fixture description, sha and URL.
report() {
  local -r context="$1"
  local -r state="$2"
  run_check "${CHECK}" "${context}" "${state}" "${DESC}" "${SHA}" "${URL}"
}

@test "--help exits 0 and prints help text" {
  run_check "${CHECK}" --help
  assert_success
  assert_output --partial 'context'
}

@test "dies when given four arguments" {
  cli_shim::record 'gh'
  run_check "${CHECK}" 'codecov/project/gates' 'failure' "${DESC}" "${SHA}"
  assert_failure
  assert_output --partial 'Expected exactly 5 arguments'
  run cli_shim::call_count 'gh'
  assert_output '0'
}

@test "dies when given six arguments" {
  cli_shim::record 'gh'
  run_check "${CHECK}" 'codecov/project/gates' 'failure' "${DESC}" "${SHA}" "${URL}" 'extra'
  assert_failure
  assert_output --partial 'Expected exactly 5 arguments'
}

@test "dies when GH_REPO is unset" {
  cli_shim::record 'gh'
  unset GH_REPO
  report 'codecov/project/gates' 'failure'
  assert_failure
  assert_output --partial 'GH_REPO'
  run cli_shim::call_count 'gh'
  assert_output '0'
}

@test "opens an issue when none is open" {
  cli_shim::record_stateful 'gh' '[]' ''
  report 'codecov/project/gates' 'failure'
  assert_success
  run cli_shim::calls 'gh'
  assert_output --partial 'issue list --repo someone/somewhere --state open --label coverage-drop'
  assert_output --partial 'issue create --repo someone/somewhere --title Coverage drop: gates --label coverage-drop'
  assert_output --partial "${DESC}"
  assert_output --partial "${SHA}"
  assert_output --partial "${URL}"
  assert_output --partial "<!-- coverage-drop sha=${SHA} -->"
  refute_output --partial 'issue comment'
}

@test "maps codecov/project to the functions flag" {
  cli_shim::record_stateful 'gh' '[]' ''
  report 'codecov/project' 'failure'
  assert_success
  run cli_shim::calls 'gh'
  assert_output --partial '--title Coverage drop: functions --label coverage-drop'
}

@test "comments on the open issue for the flag" {
  cli_shim::record_stateful 'gh' \
    '[{"number":3,"title":"Coverage drop: root"},{"number":7,"title":"Coverage drop: gates"}]' \
    '{"body":"<!-- coverage-drop sha=aaaa -->","comments":[{"body":"<!-- coverage-drop sha=bbbb -->"}]}' \
    ''
  report 'codecov/project/gates' 'failure'
  assert_success
  run cli_shim::calls 'gh'
  assert_output --partial 'issue view 7 --repo someone/somewhere --json body,comments'
  assert_output --partial 'issue comment 7 --repo someone/somewhere --body'
  assert_output --partial "<!-- coverage-drop sha=${SHA} -->"
  refute_output --partial 'issue create'
}

@test "matches the flag's issue by exact title" {
  cli_shim::record_stateful 'gh' '[{"number":9,"title":"Coverage drop: gates-old"}]' ''
  report 'codecov/project/gates' 'failure'
  assert_success
  run cli_shim::calls 'gh'
  assert_output --partial 'issue create'
  refute_output --partial 'issue view'
  refute_output --partial 'issue comment'
}

@test "a repeat for an already-reported sha is a no-op" {
  cli_shim::record_stateful 'gh' \
    '[{"number":7,"title":"Coverage drop: gates"}]' \
    "{\"body\":\"first\",\"comments\":[{\"body\":\"text\\n<!-- coverage-drop sha=${SHA} -->\"}]}"
  report 'codecov/project/gates' 'failure'
  assert_success
  run cli_shim::calls 'gh'
  refute_output --partial 'issue create'
  refute_output --partial 'issue comment'
  run cli_shim::call_count 'gh'
  assert_output '2'
}

@test "a repeat whose marker is in the issue body is a no-op" {
  cli_shim::record_stateful 'gh' \
    '[{"number":7,"title":"Coverage drop: gates"}]' \
    "{\"body\":\"text\\n<!-- coverage-drop sha=${SHA} -->\",\"comments\":[]}"
  report 'codecov/project/gates' 'failure'
  assert_success
  run cli_shim::call_count 'gh'
  assert_output '2'
}

@test "comments on an open issue whose body and comment bodies are null" {
  cli_shim::record_stateful 'gh' \
    '[{"number":7,"title":"Coverage drop: gates"}]' \
    '{"body":null,"comments":[{"body":null}]}' \
    ''
  report 'codecov/project/gates' 'failure'
  assert_success
  run cli_shim::calls 'gh'
  assert_output --partial 'issue comment 7 --repo someone/somewhere --body'
  refute_output --partial 'issue create'
}

@test "ignores a non-failure state" {
  cli_shim::record 'gh'
  report 'codecov/project/gates' 'success'
  assert_success
  run cli_shim::call_count 'gh'
  assert_output '0'
}

@test "ignores a non-project context" {
  cli_shim::record 'gh'
  report 'codecov/patch' 'failure'
  assert_success
  run cli_shim::call_count 'gh'
  assert_output '0'
}

@test "ignores a context that only shares the codecov/project prefix" {
  cli_shim::record 'gh'
  report 'codecov/projectx' 'failure'
  assert_success
  run cli_shim::call_count 'gh'
  assert_output '0'
}

@test "ignores a codecov/project/ context with an empty flag" {
  cli_shim::record 'gh'
  report 'codecov/project/' 'failure'
  assert_success
  run cli_shim::call_count 'gh'
  assert_output '0'
}

@test "fails when gh fails" {
  path_shim::add 'gh' '#!/usr/bin/env bash
exit 1'
  report 'codecov/project/gates' 'failure'
  assert_failure 1
}

@test "fails when gh returns unparsable JSON" {
  cli_shim::record_stateful 'gh' 'not json' ''
  report 'codecov/project/gates' 'failure'
  assert_failure 5
  run cli_shim::calls 'gh'
  refute_output --partial 'issue create'
}

# The poison gh exits 42 and leaves a marker. The control arm proves a bashrc-shaped
# startup file really does put it ahead of the shim; the assertion arm proves the value
# run_check uses keeps it out, so a regression is a red test, not a live issue.
@test "run_check's BASH_ENV cannot let a startup file shadow the gh shim" {
  cli_shim::record_stateful 'gh' '[]' ''
  local -r poison_dir="${BATS_TEST_TMPDIR}/poison"
  local -r marker="${BATS_TEST_TMPDIR}/poison.marker"
  mkdir --parents "${poison_dir}"
  cat > "${poison_dir}/gh" << EOF
#!/usr/bin/env bash
printf 'poisoned\n' > '${marker}'
exit 42
EOF
  chmod +x "${poison_dir}/gh"
  cat > "${BATS_TEST_TMPDIR}/fake-bashrc" << EOF
PATH='${poison_dir}':"\${PATH}"
export PATH
EOF

  BASH_ENV="${BATS_TEST_TMPDIR}/fake-bashrc" run "${CHECK}" \
    'codecov/project/gates' 'failure' "${DESC}" "${SHA}" "${URL}"
  run cat "${marker}"
  assert_success
  assert_output 'poisoned'

  rm --force -- "${marker}"
  report 'codecov/project/gates' 'failure'
  assert_success
  run cat "${marker}"
  assert_failure 1
  run cli_shim::calls 'gh'
  assert_output --partial 'issue list'
  assert_output --partial 'issue create'
}
