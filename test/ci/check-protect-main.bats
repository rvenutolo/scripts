setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-protect-main"
  RS="${BATS_TEST_TMPDIR}/rs.json"
}

good_ruleset() {
  cat > "${RS}" << 'EOF'
{
  "name": "protect-main", "target": "branch", "enforcement": "active",
  "bypass_actors": [],
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "required_signatures" },
    { "type": "pull_request", "parameters": { "allowed_merge_methods": ["merge"], "required_review_thread_resolution": true } },
    { "type": "required_status_checks", "parameters": { "strict_required_status_checks_policy": true, "required_status_checks": [ { "context": "check-scripts" } ] } }
  ]
}
EOF
}

@test "passes on a well-formed merge-only ruleset" {
  good_ruleset
  RULESET_JSON_OVERRIDE="${RS}" run "${CHECK}"
  assert_success
}

@test "fails when allowed_merge_methods is not [merge]" {
  good_ruleset
  jq '(.rules[] | select(.type=="pull_request") | .parameters.allowed_merge_methods) = ["rebase"]' "${RS}" > "${RS}.x" && mv "${RS}.x" "${RS}"
  RULESET_JSON_OVERRIDE="${RS}" run "${CHECK}"
  assert_failure
  assert_output --partial 'allowed_merge_methods'
}

@test "fails when required_signatures rule is missing" {
  good_ruleset
  jq 'del(.rules[] | select(.type=="required_signatures"))' "${RS}" > "${RS}.x" && mv "${RS}.x" "${RS}"
  RULESET_JSON_OVERRIDE="${RS}" run "${CHECK}"
  assert_failure
  assert_output --partial 'required_signatures'
}

@test "fails when required_linear_history is present" {
  good_ruleset
  jq '.rules += [{ "type": "required_linear_history" }]' "${RS}" > "${RS}.x" && mv "${RS}.x" "${RS}"
  RULESET_JSON_OVERRIDE="${RS}" run "${CHECK}"
  assert_failure
  assert_output --partial 'required_linear_history'
}

@test "fails when bypass_actors is non-empty" {
  good_ruleset
  jq '.bypass_actors = [{ "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" }]' "${RS}" > "${RS}.x" && mv "${RS}.x" "${RS}"
  RULESET_JSON_OVERRIDE="${RS}" run "${CHECK}"
  assert_failure
  assert_output --partial 'bypass_actors'
}

@test "fails when file missing" {
  RULESET_JSON_OVERRIDE="${BATS_TEST_TMPDIR}/nope.json" run "${CHECK}"
  assert_failure
  assert_output --partial 'not found'
}

@test "validates the real in-tree ruleset by default" {
  run "${CHECK}"
  assert_success
}

@test "dies when given an argument" {
  RULESET_JSON_OVERRIDE="${RS}" run "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}
