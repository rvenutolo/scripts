setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-upload-artifact-strict"
  WF="${BATS_TEST_TMPDIR}/wf"
  ACT="${BATS_TEST_TMPDIR}/actions/myaction"
  mkdir -p "${WF}" "${ACT}"
}

# Run with both override seams pointed at the test tmpdirs.
run_check() {
  WORKFLOWS_DIR_OVERRIDE="${WF}" ACTIONS_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/actions" run "${CHECK}" "$@"
}

@test "passes when a non-allowlisted upload sets if-no-files-found: error" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/upload-artifact@v4
        with:
          name: build-output
          path: dist/
          if-no-files-found: error
EOF
  run_check
  assert_success
}

@test "passes when an allowlisted name uses warn" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: coverage/
          if-no-files-found: warn
EOF
  run_check
  assert_success
}

@test "passes when an allowlisted name uses ignore" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: coverage/
          if-no-files-found: ignore
EOF
  run_check
  assert_success
}

@test "passes when an allowlisted name uses error (stricter is fine)" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: coverage/
          if-no-files-found: error
EOF
  run_check
  assert_success
}

@test "passes when there are no upload-artifact steps" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - uses: actions/checkout@v4
EOF
  run_check
  assert_success
}

@test "passes for an upload in a composite action with error" {
  cat > "${ACT}/action.yml" << 'EOF'
name: my action
runs:
  using: composite
  steps:
    - uses: actions/upload-artifact@v4
      with:
        name: build-output
        path: dist/
        if-no-files-found: error
EOF
  run_check
  assert_success
}

@test "fails when if-no-files-found is omitted" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - uses: actions/upload-artifact@v4
        with:
          name: build-output
          path: dist/
EOF
  run_check
  assert_failure
  assert_output --partial 'a.yml'
  assert_output --partial 'if-no-files-found'
}

@test "fails when a non-allowlisted name uses warn" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - uses: actions/upload-artifact@v4
        with:
          name: build-output
          path: dist/
          if-no-files-found: warn
EOF
  run_check
  assert_failure
  assert_output --partial 'must be error'
}

@test "fails on an invalid if-no-files-found value" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - uses: actions/upload-artifact@v4
        with:
          name: build-output
          path: dist/
          if-no-files-found: eror
EOF
  run_check
  assert_failure
  assert_output --partial 'invalid'
}

@test "counts multiple offenders" {
  cat > "${WF}/a.yml" << 'EOF'
on: push
jobs:
  build:
    steps:
      - uses: actions/upload-artifact@v4
        with:
          name: one
          path: a/
          if-no-files-found: warn
      - uses: actions/upload-artifact@v4
        with:
          name: two
          path: b/
EOF
  run_check
  assert_failure
  assert_output --partial '2 upload-artifact'
}

@test "dies with an unexpected argument" {
  run "${CHECK}" extra-arg
  assert_failure
}

@test "prints help and exits 0 with --help" {
  run "${CHECK}" --help
  assert_success
}
