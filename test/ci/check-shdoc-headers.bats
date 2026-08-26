setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  load '../test_helper/git_fixture'
  load '../test_helper/path_shim'
  # Capture the real check path BEFORE any cd into the fixture repo — REPO_DIR
  # from common.bash points at the real repo here, and the tests cd away.
  CHECK="${REPO_DIR}/.ci/check-shdoc-headers"
  REAL_SCRIPTS_DIR="${SCRIPTS_DIR}"
  REPO="${BATS_TEST_TMPDIR}/repo"
  # The fixture mirrors the real repo layout: SCRIPTS_DIR is repo-root/scripts.
  # The check derives its scan root from `git rev-parse --show-toplevel`, so the
  # scripts/ layer is required for its scans to resolve — and having it lets a
  # test point SCRIPTS_DIR somewhere else entirely, which is how the scan-root
  # pins below discriminate.
  SCRIPTS="${REPO}/scripts"

  # The check sources "${SCRIPTS_DIR}/.functions.bash", which loops over
  # "${SCRIPTS_DIR}/functions/*.bash". Symlinking the REAL .functions.bash and
  # functions/ library into the fixture keeps sourcing working AND keeps the
  # library-file audit clean, since the real library is fully compliant.
  # Top-level FAILURE cases are driven through fixture scripts dropped into
  # scripts/non-interactive/. The fixture has no .ci/ dir, so that scan
  # contributes nothing.
  mkdir -p "${SCRIPTS}/non-interactive" "${SCRIPTS}/functions"
  git_fixture::init "${REPO}"
  ln --symbolic "${REAL_SCRIPTS_DIR}/.functions.bash" "${SCRIPTS}/.functions.bash"
  local lib
  for lib in "${REAL_SCRIPTS_DIR}"/functions/*.bash; do
    ln --symbolic "${lib}" "${SCRIPTS}/functions/$(basename -- "${lib}")"
  done

  # A clean, fully-annotated top-level fixture script so the default tree passes.
  cat > "${SCRIPTS}/non-interactive/good-script" << 'EOF'
#!/usr/bin/env bash

# @description A clean fixture script.
# @noargs

set -Eeuo pipefail
IFS=$'\n\t'

echo hi
EOF
  chmod +x "${SCRIPTS}/non-interactive/good-script"

  # A clean root-level executable. Production repo roots always hold several
  # (check-scripts, run-tests, ...), and shell_scripts::find_root_only exits 1
  # on an empty root precisely so a gate cannot read an unscanned root as a
  # clean one. A fixture with no root scripts would not mirror any real tree,
  # and would force the check to tolerate an exit that never happens in
  # production.
  cat > "${REPO}/good-root-script" << 'EOF'
#!/usr/bin/env bash

# @description A clean fixture script living at the repo root.
# @noargs

set -Eeuo pipefail
IFS=$'\n\t'

echo hi
EOF
  chmod +x "${REPO}/good-root-script"
}

# Run the check against the fixture repo. Caller cds into ${REPO} first so the
# check's `git rev-parse --show-toplevel` resolves to the fixture.
run_check() {
  SCRIPTS_DIR="${SCRIPTS}" run "${CHECK}" "$@"
}

@test "passes on a clean fixture tree (annotated script + real library)" {
  cd "${REPO}"
  run_check
  assert_success
}

@test "fails when a top-level script is missing its file-level @description" {
  cat > "${SCRIPTS}/non-interactive/no-desc" << 'EOF'
#!/usr/bin/env bash

# @noargs

set -Eeuo pipefail
IFS=$'\n\t'

echo hi
EOF
  chmod +x "${SCRIPTS}/non-interactive/no-desc"
  cd "${REPO}"
  run_check
  assert_failure
  assert_output --partial 'non-interactive/no-desc'
  assert_output --partial 'missing file-level @description'
}

@test "fails when a top-level script has an unannotated helper function" {
  cat > "${SCRIPTS}/non-interactive/bad-helper" << 'EOF'
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
  chmod +x "${SCRIPTS}/non-interactive/bad-helper"
  cd "${REPO}"
  run_check
  assert_failure
  assert_output --partial 'non-interactive/bad-helper'
  assert_output --partial 'helper function missing shdoc annotation: do_thing'
}

@test "passes when a helper function is properly annotated" {
  cat > "${SCRIPTS}/non-interactive/good-helper" << 'EOF'
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
  chmod +x "${SCRIPTS}/non-interactive/good-helper"
  cd "${REPO}"
  run_check
  assert_success
}

@test "ignores an unannotated main function (exempt by file-level header)" {
  cat > "${SCRIPTS}/non-interactive/with-main" << 'EOF'
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
  chmod +x "${SCRIPTS}/non-interactive/with-main"
  cd "${REPO}"
  run_check
  assert_success
}

@test "reports every failing script when several are broken" {
  cat > "${SCRIPTS}/non-interactive/no-desc" << 'EOF'
#!/usr/bin/env bash

# @noargs

set -Eeuo pipefail
IFS=$'\n\t'

echo hi
EOF
  chmod +x "${SCRIPTS}/non-interactive/no-desc"
  cat > "${SCRIPTS}/non-interactive/bad-helper" << 'EOF'
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
  chmod +x "${SCRIPTS}/non-interactive/bad-helper"
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

@test "prints help under a Stderr heading and exits 0 for --help" {
  # The violation output goes to stderr (audit_one / audit_library_one both end
  # in >&2), and args::handle_help_flag renders the file-level shdoc tags into
  # --help. A 'Stdout:' heading here would mean the header tag is mislabelled.
  cd "${REPO}"
  run_check --help
  assert_success
  assert_output --partial 'Stderr:'
  refute_output --partial 'Stdout:'
}

@test "fails when a top-level script carries the scaffold placeholder description" {
  cat > "${SCRIPTS}/non-interactive/scaffolded" << 'EOF'
#!/usr/bin/env bash

# @description TODO: describe what this script does.
# @noargs

set -Eeuo pipefail
IFS=$'\n\t'

echo hi
EOF
  chmod +x "${SCRIPTS}/non-interactive/scaffolded"
  cd "${REPO}"
  run_check
  assert_failure
  assert_output --partial 'placeholder'
  assert_output --partial 'scaffolded'
}

@test "fails when a library-sourcing script omits the help-flag call" {
  cat > "${SCRIPTS}/non-interactive/no-help-flag" << 'EOF'
#!/usr/bin/env bash

# @description A script that forgot its help flag.
# @noargs

set -Eeuo pipefail
IFS=$'\n\t'

source "${SCRIPTS_DIR}/.functions.bash"
log::enable_err_trap
args::check_no_args "$@"
EOF
  chmod +x "${SCRIPTS}/non-interactive/no-help-flag"
  cd "${REPO}"
  run_check
  assert_failure
  assert_output --partial 'args::handle_help_flag'
  assert_output --partial 'no-help-flag'
}

@test "passes when a library-sourcing script calls the help flag" {
  cat > "${SCRIPTS}/non-interactive/with-help-flag" << 'EOF'
#!/usr/bin/env bash

# @description A script that remembers its help flag.
# @noargs

set -Eeuo pipefail
IFS=$'\n\t'

source "${SCRIPTS_DIR}/.functions.bash"
log::enable_err_trap
args::handle_help_flag "$@"
args::check_no_args "$@"
EOF
  chmod +x "${SCRIPTS}/non-interactive/with-help-flag"
  cd "${REPO}"
  run_check
  assert_success
}

@test "passes when a pass-through script omits the help-flag call" {
  cat > "${SCRIPTS}/non-interactive/passthrough" << 'EOF'
#!/usr/bin/env bash

# @description Forward everything to the real tool.
# @arg $@ args Arguments forwarded verbatim.

set -Eeuo pipefail
IFS=$'\n\t'

source "${SCRIPTS_DIR}/.functions.bash"
log::enable_err_trap
# pass-through: any arg count valid; the real tool owns --help

exec true "$@"
EOF
  chmod +x "${SCRIPTS}/non-interactive/passthrough"
  cd "${REPO}"
  run_check
  assert_success
}

@test "passes when a standalone script omits the help-flag call" {
  cat > "${SCRIPTS}/non-interactive/standalone" << 'EOF'
#!/usr/bin/env bash

# @description A standalone script that never sources the library.
# @noargs

set -Eeuo pipefail
IFS=$'\n\t'

echo hi
EOF
  chmod +x "${SCRIPTS}/non-interactive/standalone"
  cd "${REPO}"
  run_check
  assert_success
}

@test "fails when the help flag is named only in header prose" {
  cat > "${SCRIPTS}/non-interactive/prose-only" << 'EOF'
#!/usr/bin/env bash

# @description A script whose header discusses args::handle_help_flag
#              without ever calling it.
# @noargs

set -Eeuo pipefail
IFS=$'\n\t'

source "${SCRIPTS_DIR}/.functions.bash"
log::enable_err_trap
args::check_no_args "$@"
EOF
  chmod +x "${SCRIPTS}/non-interactive/prose-only"
  cd "${REPO}"
  run_check
  assert_failure
  assert_output --partial 'prose-only'
}

# The two tests below deliberately do NOT use run_check: they point SCRIPTS_DIR at
# the REAL repo while cwd is the fixture. A scan rooted at SCRIPTS_DIR audits the
# real tree, which is compliant, and reports success — the false green of #250. The
# audit must follow the repo it was invoked in and catch the fixture's violation.

@test "audits top-level scripts from the repo it runs in, not SCRIPTS_DIR" {
  cat > "${SCRIPTS}/non-interactive/no-desc" << 'EOF'
#!/usr/bin/env bash

# @noargs

set -Eeuo pipefail
IFS=$'\n\t'

echo hi
EOF
  chmod +x "${SCRIPTS}/non-interactive/no-desc"
  cd "${REPO}"
  SCRIPTS_DIR="${REAL_SCRIPTS_DIR}" run "${CHECK}"
  assert_failure
  assert_output --partial 'non-interactive/no-desc'
  assert_output --partial 'missing file-level @description'
}

@test "audits library files from the repo it runs in, not SCRIPTS_DIR" {
  # A real file, not a symlink: the fixture library otherwise mirrors the compliant
  # real library entirely.
  cat > "${SCRIPTS}/functions/broken.bash" << 'EOF'
#!/usr/bin/env bash

function broken_thing() {
  echo thing
}
EOF
  cd "${REPO}"
  SCRIPTS_DIR="${REAL_SCRIPTS_DIR}" run "${CHECK}"
  assert_failure
  assert_output --partial 'broken.bash'
  assert_output --partial 'broken_thing'
}

@test "audit_library_one is not vacuous for namespaced library functions" {
  cat > "${SCRIPTS}/functions/broken_ns.bash" << 'EOF'
#!/usr/bin/env bash

function broken::unannotated() {
  echo hi
}
EOF
  cd "${REPO}"
  run_check
  assert_failure
  assert_output --partial 'broken_ns.bash'
  assert_output --partial 'broken::unannotated'
}

@test "fails when a library function annotation carries placeholder text" {
  cat > "${SCRIPTS}/functions/scaffolded.bash" << 'EOF'
#!/usr/bin/env bash

# @description TODO: describe what this does.
# @arg $1 thing
function scaffolded::thing() {
  echo hi
}
EOF
  cd "${REPO}"
  run_check
  assert_failure
  assert_output --partial 'scaffolded.bash'
  assert_output --partial 'scaffolded::thing'
  assert_output --partial 'placeholder'
}

@test "fails when a top-level script helper annotation carries placeholder text" {
  cat > "${SCRIPTS}/non-interactive/scaffolded-helper" << 'EOF'
#!/usr/bin/env bash

# @description A clean file-level header.
# @noargs

set -Eeuo pipefail
IFS=$'\n\t'

# @description TODO: describe this helper.
# @noargs
function collect_things() {
  echo hi
}

collect_things
EOF
  chmod +x "${SCRIPTS}/non-interactive/scaffolded-helper"
  cd "${REPO}"
  run_check
  assert_failure
  assert_output --partial 'scaffolded-helper'
  assert_output --partial 'collect_things'
  assert_output --partial 'placeholder'
}

@test "aborts loudly when a tool inside the audit fails instead of reading clean" {
  # Pins the #296 producer conversion: before it, audit_one ran as an `if`
  # condition, so a failed scan left its temp file empty and the emptiness test
  # read as "clean" — this exact setup exited 0 (#294, #297). The shim targets
  # gawk, not awk: only shdoc.bash uses gawk, so the failure is confined to the
  # audit, while a global awk shim destabilizes the whole run (#297).
  path_shim::add 'gawk' '#!/usr/bin/env bash
exit 1'
  cd "${REPO}"
  # Neutralize BASH_ENV so the check's bash startup does not re-source ~/.bashrc,
  # which would re-prepend the real gawk ahead of the shim. SAFE_BASH_ENV rather
  # than '' keeps kcov's trace helper attached (#322).
  BASH_ENV="${SAFE_BASH_ENV}" run_check
  assert_failure 1
  assert_output --partial 'ERROR:'
  assert_output --partial 'gawk'
}
