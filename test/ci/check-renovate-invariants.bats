#!/usr/bin/env bash

setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-renovate-invariants"
  CFG="${BATS_TEST_TMPDIR}/renovate.json"
}

@test "passes on a config carrying all invariants" {
  cat > "${CFG}" << 'EOF'
{
  "extends": ["config:recommended", "helpers:pinGitHubActionDigests"],
  "minimumReleaseAge": "7 days",
  "packageRules": [
    { "matchManagers": ["github-actions"], "automerge": true, "pinDigests": true }
  ]
}
EOF
  RENOVATE_JSON_OVERRIDE="${CFG}" run "${CHECK}"
  assert_success
}

@test "fails when pinGitHubActionDigests missing" {
  cat > "${CFG}" << 'EOF'
{ "extends": ["config:recommended"], "minimumReleaseAge": "7 days",
  "packageRules": [ { "matchManagers": ["github-actions"], "pinDigests": true } ] }
EOF
  RENOVATE_JSON_OVERRIDE="${CFG}" run "${CHECK}"
  assert_failure
  assert_output --partial 'pinGitHubActionDigests'
}

@test "fails when minimumReleaseAge unset" {
  cat > "${CFG}" << 'EOF'
{ "extends": ["helpers:pinGitHubActionDigests"],
  "packageRules": [ { "matchManagers": ["github-actions"], "pinDigests": true } ] }
EOF
  RENOVATE_JSON_OVERRIDE="${CFG}" run "${CHECK}"
  assert_failure
  assert_output --partial 'minimumReleaseAge'
}

@test "fails on top-level automerge" {
  cat > "${CFG}" << 'EOF'
{ "extends": ["helpers:pinGitHubActionDigests"], "minimumReleaseAge": "7 days",
  "automerge": true,
  "packageRules": [ { "matchManagers": ["github-actions"], "pinDigests": true } ] }
EOF
  RENOVATE_JSON_OVERRIDE="${CFG}" run "${CHECK}"
  assert_failure
  assert_output --partial 'automerge'
}

@test "fails when github-actions rule lacks pinDigests" {
  cat > "${CFG}" << 'EOF'
{ "extends": ["helpers:pinGitHubActionDigests"], "minimumReleaseAge": "7 days",
  "packageRules": [ { "matchManagers": ["github-actions"], "automerge": true } ] }
EOF
  RENOVATE_JSON_OVERRIDE="${CFG}" run "${CHECK}"
  assert_failure
  assert_output --partial 'pinDigests'
}

@test "fails when config file missing" {
  RENOVATE_JSON_OVERRIDE="${BATS_TEST_TMPDIR}/nope.json" run "${CHECK}"
  assert_failure
  assert_output --partial 'not found'
}

@test "dies when given an argument" {
  RENOVATE_JSON_OVERRIDE="${CFG}" run "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}
