setup() {
  load '../test_helper/common'
  DIFF="${SCRIPTS_DIR}/.ci/diff-ruleset"
  A="${BATS_TEST_TMPDIR}/a.json"
  B="${BATS_TEST_TMPDIR}/b.json"
}

@test "matches when only integration_id / order differ" {
  cat > "${A}" << 'EOF'
{ "name": "protect-main", "target": "branch", "enforcement": "active", "bypass_actors": [],
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "id": 123, "created_at": "x",
  "rules": [
    { "type": "required_status_checks", "parameters": { "strict_required_status_checks_policy": true,
      "required_status_checks": [ { "context": "bats", "integration_id": 15368 }, { "context": "actionlint" } ] } },
    { "type": "deletion" } ] }
EOF
  cat > "${B}" << 'EOF'
{ "name": "protect-main", "target": "branch", "enforcement": "active", "bypass_actors": [],
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "required_status_checks", "parameters": { "strict_required_status_checks_policy": true,
      "required_status_checks": [ { "context": "actionlint" }, { "context": "bats" } ] } } ] }
EOF
  run "${DIFF}" "${A}" "${B}"
  assert_success
}

@test "reports drift when a required context differs" {
  cat > "${A}" << 'EOF'
{ "name": "protect-main", "target": "branch", "enforcement": "active", "bypass_actors": [],
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [ { "type": "required_status_checks", "parameters": { "strict_required_status_checks_policy": true,
    "required_status_checks": [ { "context": "bats" } ] } } ] }
EOF
  cat > "${B}" << 'EOF'
{ "name": "protect-main", "target": "branch", "enforcement": "active", "bypass_actors": [],
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [ { "type": "required_status_checks", "parameters": { "strict_required_status_checks_policy": true,
    "required_status_checks": [ { "context": "actionlint" } ] } } ] }
EOF
  run "${DIFF}" "${A}" "${B}"
  assert_failure
  assert_output --partial 'drift'
}

@test "reports drift when bypass_actors differ" {
  cat > "${A}" << 'EOF'
{ "name": "protect-main", "target": "branch", "enforcement": "active",
  "bypass_actors": [ { "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" } ],
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } }, "rules": [] }
EOF
  cat > "${B}" << 'EOF'
{ "name": "protect-main", "target": "branch", "enforcement": "active", "bypass_actors": [],
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } }, "rules": [] }
EOF
  run "${DIFF}" "${A}" "${B}"
  assert_failure
}

@test "dies without exactly two args" {
  run "${DIFF}" "${A}"
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}
