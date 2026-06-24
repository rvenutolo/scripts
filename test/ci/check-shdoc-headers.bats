setup() {
  load '../test_helper/common'
  # Capture the real check path BEFORE any cd into the fixture repo — REPO_DIR
  # from common.bash points at the real repo here, and the tests cd away.
  CHECK="${REPO_DIR}/.ci/check-shdoc-headers"
  REAL_SCRIPTS_DIR="${SCRIPTS_DIR}"
  REPO="${BATS_TEST_TMPDIR}/repo"

  # The check sources "${SCRIPTS_DIR}/.functions.bash", which loops over
  # "${SCRIPTS_DIR}/functions/*.bash". It also AUDITS "${SCRIPTS_DIR}/functions/*.bash"
  # (library files) and resolves the repo root via `git rev-parse --show-toplevel`
  # for its .ci/ and root scans.
  #
  # Isolation approach: build a temp git repo as the fixture SCRIPTS_DIR and
  # symlink the REAL .functions.bash + functions/ library into it. That keeps
  # sourcing working AND keeps the library-file audit clean (the real library
  # is fully compliant). Top-level FAILURE cases are then driven through fixture
  # scripts dropped into non-interactive/, which exercise the same audit_one /
  # shdoc::* code paths. The temp repo has no .ci/ dir and no shebang-bearing
  # root files, so those scans contribute nothing — the audit operates on the
  # SCRIPTS_DIR fixtures only.
  mkdir -p "${REPO}/non-interactive" "${REPO}/functions"
  git init --quiet "${REPO}"
  ln --symbolic "${REAL_SCRIPTS_DIR}/.functions.bash" "${REPO}/.functions.bash"
  local lib
  for lib in "${REAL_SCRIPTS_DIR}"/functions/*.bash; do
    ln --symbolic "${lib}" "${REPO}/functions/$(basename -- "${lib}")"
  done

  # A clean, fully-annotated top-level fixture script so the default tree passes.
  cat > "${REPO}/non-interactive/good-script" << 'EOF'
#!/usr/bin/env bash

# @description A clean fixture script.
# @noargs

set -Eeuo pipefail
IFS=$'\n\t'

echo hi
EOF
  chmod +x "${REPO}/non-interactive/good-script"
}

# Run the check against the fixture repo. Caller cds into ${REPO} first so the
# check's `git rev-parse --show-toplevel` resolves to the fixture.
run_check() {
  SCRIPTS_DIR="${REPO}" run "${CHECK}" "$@"
}

@test "passes on a clean fixture tree (annotated script + real library)" {
  cd "${REPO}"
  run_check
  assert_success
}

@test "fails when a top-level script is missing its file-level @description" {
  cat > "${REPO}/non-interactive/no-desc" << 'EOF'
#!/usr/bin/env bash

# @noargs

set -Eeuo pipefail
IFS=$'\n\t'

echo hi
EOF
  chmod +x "${REPO}/non-interactive/no-desc"
  cd "${REPO}"
  run_check
  assert_failure
  assert_output --partial 'non-interactive/no-desc'
  assert_output --partial 'missing file-level @description'
}

@test "fails when a top-level script has an unannotated helper function" {
  cat > "${REPO}/non-interactive/bad-helper" << 'EOF'
#!/usr/bin/env bash

# @description Has an unannotated helper.
# @noargs

set -Eeuo pipefail
IFS=$'\n\t'

function do_thing() {
  echo thing
}

do_thing
EOF
  chmod +x "${REPO}/non-interactive/bad-helper"
  cd "${REPO}"
  run_check
  assert_failure
  assert_output --partial 'non-interactive/bad-helper'
  assert_output --partial 'helper function missing shdoc annotation: do_thing'
}

@test "passes when a helper function is properly annotated" {
  cat > "${REPO}/non-interactive/good-helper" << 'EOF'
#!/usr/bin/env bash

# @description Has a properly annotated helper.
# @noargs

set -Eeuo pipefail
IFS=$'\n\t'

# @description Do a thing.
# @noargs
function do_thing() {
  echo thing
}

do_thing
EOF
  chmod +x "${REPO}/non-interactive/good-helper"
  cd "${REPO}"
  run_check
  assert_success
}

@test "ignores an unannotated main function (exempt by file-level header)" {
  cat > "${REPO}/non-interactive/with-main" << 'EOF'
#!/usr/bin/env bash

# @description A script whose only function is main.
# @noargs

set -Eeuo pipefail
IFS=$'\n\t'

function main() {
  echo hi
}

main "$@"
EOF
  chmod +x "${REPO}/non-interactive/with-main"
  cd "${REPO}"
  run_check
  assert_success
}

@test "reports every failing script when several are broken" {
  cat > "${REPO}/non-interactive/no-desc" << 'EOF'
#!/usr/bin/env bash

# @noargs

set -Eeuo pipefail
IFS=$'\n\t'

echo hi
EOF
  chmod +x "${REPO}/non-interactive/no-desc"
  cat > "${REPO}/non-interactive/bad-helper" << 'EOF'
#!/usr/bin/env bash

# @description Has an unannotated helper.
# @noargs

set -Eeuo pipefail
IFS=$'\n\t'

function do_thing() {
  echo thing
}

do_thing
EOF
  chmod +x "${REPO}/non-interactive/bad-helper"
  cd "${REPO}"
  run_check
  assert_failure
  assert_output --partial 'non-interactive/no-desc'
  assert_output --partial 'non-interactive/bad-helper'
}

@test "dies when given an argument" {
  cd "${REPO}"
  run_check oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}
