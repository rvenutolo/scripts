setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  load '../test_helper/cli_shim'
  CHECK="${REPO_DIR}/.ci/apply-repo-settings"
}

# .ci/apply-repo-settings derives its own repo root via `git rev-parse
# --show-toplevel` (it feeds .github/rulesets/protect-main.json to gh).
# common.bash's #248 hardening leaves CWD at BATS_TEST_TMPDIR (outside any git
# repo) by design, so cd into REPO_DIR before every invocation.
#
# BASH_ENV is cleared on every invocation: the script's own `#!/usr/bin/env bash`
# startup re-sources ~/.bashrc, which re-prepends the real nix PATH and would
# shadow the gh shim with the REAL gh. This script mutates a live GitHub repo,
# so an unshimmed invocation is not a failed test — it is an unintended write.
run_check() {
  cd "${REPO_DIR}" || return 1
  BASH_ENV='' run "$@"
}

# shim_gh <rulesets_query_output> — stub gh across the five calls the script
# makes, in order: PATCH repo settings, PUT vulnerability-alerts, PUT
# automated-security-fixes, GET rulesets (whose stdout decides create-vs-update),
# then the ruleset POST or PUT.
shim_gh() {
  local -r rulesets_output="$1"
  cli_shim::record_stateful 'gh' '' '' '' "${rulesets_output}" ''
}

@test "--help exits 0 and prints help text" {
  run_check "${CHECK}" --help
  assert_success
  assert_output --partial 'repo'
}

@test "dies when given two arguments" {
  run_check "${CHECK}" one two
  assert_failure
  assert_output --partial 'Expected at most 1 argument'
}

@test "dies when gh is not installed" {
  path_shim::mkbin
  PATH="${BATS_TEST_TMPDIR}/bin:/usr/bin:/bin" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'gh'
}

@test "defaults to the rvenutolo/scripts slug" {
  shim_gh ''
  run_check "${CHECK}"
  assert_success
  run cli_shim::calls 'gh'
  assert_output --partial 'repos/rvenutolo/scripts'
}

@test "uses an explicitly passed slug instead of the default" {
  shim_gh ''
  run_check "${CHECK}" 'someone/elsewhere'
  assert_success
  run cli_shim::calls 'gh'
  assert_output --partial 'repos/someone/elsewhere'
  refute_output --partial 'repos/rvenutolo/scripts'
}

@test "PATCHes the merge-commit settings the repo mandates" {
  shim_gh ''
  run_check "${CHECK}"
  assert_success
  run cli_shim::calls 'gh'
  # Merge commit is the only allowed merge method; rebase and squash are off.
  assert_output --partial 'allow_merge_commit=true'
  assert_output --partial 'allow_rebase_merge=false'
  assert_output --partial 'allow_squash_merge=false'
  # The PR title/body become the merge-commit subject/message.
  assert_output --partial 'merge_commit_title=PR_TITLE'
  assert_output --partial 'merge_commit_message=PR_BODY'
}

@test "enables vulnerability alerts and automated security fixes" {
  shim_gh ''
  run_check "${CHECK}"
  assert_success
  run cli_shim::calls 'gh'
  assert_output --partial 'vulnerability-alerts'
  assert_output --partial 'automated-security-fixes'
}

@test "creates the protect-main ruleset when the repo has none" {
  shim_gh ''
  run_check "${CHECK}"
  assert_success
  assert_output --partial 'creating protect-main ruleset'
  refute_output --partial 'updating protect-main ruleset'
  run cli_shim::calls 'gh'
  assert_output --partial '--method POST repos/rvenutolo/scripts/rulesets'
}

@test "updates the protect-main ruleset when one already exists" {
  shim_gh '4815162342'
  run_check "${CHECK}"
  assert_success
  assert_output --partial 'updating protect-main ruleset (id 4815162342)'
  refute_output --partial 'creating protect-main ruleset'
  run cli_shim::calls 'gh'
  assert_output --partial '--method PUT repos/rvenutolo/scripts/rulesets/4815162342'
}

@test "feeds the tracked ruleset JSON to gh rather than an inline body" {
  shim_gh ''
  run_check "${CHECK}"
  assert_success
  run cli_shim::calls 'gh'
  assert_output --partial '--input'
  assert_output --partial '.github/rulesets/protect-main.json'
}

@test "fails when a gh call fails" {
  path_shim::add 'gh' '#!/usr/bin/env bash
exit 1'
  run_check "${CHECK}"
  assert_failure
}

@test "reports the repo it is applying to before mutating it" {
  shim_gh ''
  run_check "${CHECK}"
  assert_success
  assert_output --partial 'applying repo settings to rvenutolo/scripts'
  assert_output --partial 'done'
}
