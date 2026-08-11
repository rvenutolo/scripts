#!/usr/bin/env bash

setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-renovate-invariants"
  CFG="${BATS_TEST_TMPDIR}/renovate.json"
}

# .ci/check-renovate-invariants derives its own repo root via
# `git rev-parse --show-toplevel`. common.bash's #248 hardening leaves CWD at
# BATS_TEST_TMPDIR (outside any git repo) by design, so cd into REPO_DIR before
# every invocation — this test targets the real repo.
run_check() {
  cd "${REPO_DIR}" || return 1
  run "$@"
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
  RENOVATE_JSON_OVERRIDE="${CFG}" run_check "${CHECK}"
  assert_success
}

@test "fails when pinGitHubActionDigests missing" {
  cat > "${CFG}" << 'EOF'
{ "extends": ["config:recommended"], "minimumReleaseAge": "7 days",
  "packageRules": [ { "matchManagers": ["github-actions"], "pinDigests": true } ] }
EOF
  RENOVATE_JSON_OVERRIDE="${CFG}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'pinGitHubActionDigests'
}

@test "fails when minimumReleaseAge unset" {
  cat > "${CFG}" << 'EOF'
{ "extends": ["helpers:pinGitHubActionDigests"],
  "packageRules": [ { "matchManagers": ["github-actions"], "pinDigests": true } ] }
EOF
  RENOVATE_JSON_OVERRIDE="${CFG}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'minimumReleaseAge'
}

@test "fails on top-level automerge" {
  cat > "${CFG}" << 'EOF'
{ "extends": ["helpers:pinGitHubActionDigests"], "minimumReleaseAge": "7 days",
  "automerge": true,
  "packageRules": [ { "matchManagers": ["github-actions"], "pinDigests": true } ] }
EOF
  RENOVATE_JSON_OVERRIDE="${CFG}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'automerge'
}

@test "fails when github-actions rule lacks pinDigests" {
  cat > "${CFG}" << 'EOF'
{ "extends": ["helpers:pinGitHubActionDigests"], "minimumReleaseAge": "7 days",
  "packageRules": [ { "matchManagers": ["github-actions"], "automerge": true } ] }
EOF
  RENOVATE_JSON_OVERRIDE="${CFG}" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'pinDigests'
}

@test "fails when config file missing" {
  RENOVATE_JSON_OVERRIDE="${BATS_TEST_TMPDIR}/nope.json" run_check "${CHECK}"
  assert_failure
  assert_output --partial 'not found'
}

@test "dies when given an argument" {
  RENOVATE_JSON_OVERRIDE="${CFG}" run_check "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}
