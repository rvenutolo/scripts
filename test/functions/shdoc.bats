setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/strings.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/shdoc.bash"
}

@test "shdoc::file_has_description true when @description present in header" {
  local f="${BATS_TEST_TMPDIR}/s1"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description Does a thing.
# @noargs

set -Eeuo pipefail
EOF
  run shdoc::file_has_description "${f}"
  assert_success
}

@test "shdoc::file_has_description false when no @description anywhere" {
  local f="${BATS_TEST_TMPDIR}/s2"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

set -Eeuo pipefail
echo hi
EOF
  run shdoc::file_has_description "${f}"
  assert_failure
}

@test "shdoc::file_has_description false when @description appears only after set -Eeuo" {
  local f="${BATS_TEST_TMPDIR}/s3"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

set -Eeuo pipefail

# @description placed wrong — after strict mode
some_command
EOF
  run shdoc::file_has_description "${f}"
  assert_failure
}

@test "shdoc::file_has_description tolerates misc/-style scripts without strict mode line" {
  local f="${BATS_TEST_TMPDIR}/s4"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description Standalone misc/ script.
# @noargs

trap 'echo err' ERR
echo hi
EOF
  run shdoc::file_has_description "${f}"
  assert_success
}

@test "shdoc::file_has_description dies with 0 args" {
  run shdoc::file_has_description
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "shdoc::file_has_description dies with 2 args" {
  run shdoc::file_has_description a b
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "shdoc::find_unannotated_functions returns names of helpers missing @-tag above" {
  local f="${BATS_TEST_TMPDIR}/s5"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description top
# @noargs

set -Eeuo pipefail

function helper_a() {
  :
}

# @description annotated
function helper_b() {
  :
}

function main() {
  :
}

main "$@"
EOF
  run shdoc::find_unannotated_functions "${f}"
  assert_success
  assert_line 'helper_a'
  refute_line 'helper_b'
  refute_line 'main'
}

@test "shdoc::find_unannotated_functions ignores bare function() form" {
  # Repo convention requires `function name() {`; parser ignores bare-form defs.
  local f="${BATS_TEST_TMPDIR}/s6"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description top
# @noargs

bare_form() {
  :
}
EOF
  run shdoc::find_unannotated_functions "${f}"
  assert_success
  assert_output ''
}

@test "shdoc::find_unannotated_functions treats shellcheck directive lines as non-annotation" {
  local f="${BATS_TEST_TMPDIR}/s7"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description top
# @noargs

# shellcheck disable=SC2034
function helper_c() {
  :
}
EOF
  run shdoc::find_unannotated_functions "${f}"
  assert_success
  assert_line 'helper_c'
}

@test "shdoc::find_unannotated_functions dies with 0 args" {
  run shdoc::find_unannotated_functions
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "shdoc::find_unannotated_functions emits nothing for a file with no helper functions" {
  local f="${BATS_TEST_TMPDIR}/s8"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description top
# @noargs

set -Eeuo pipefail
echo done
EOF
  run shdoc::find_unannotated_functions "${f}"
  assert_success
  assert_output ''
}

@test "shdoc::file_has_description fallback path works under strict mode" {
  local f="${BATS_TEST_TMPDIR}/misc_style"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description Misc-style standalone script with no set -Eeuo pipefail line.
# @noargs

trap 'echo err' ERR
echo hello
EOF
  run bash -c "
    set -Eeuo pipefail
    trap 'echo CAUGHT_ERR_TRAP >&2; exit 99' ERR
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/strings.bash'
    source '${SCRIPTS_DIR}/functions/shdoc.bash'
    shdoc::file_has_description '${f}'
  "
  assert_success
  refute_output --partial 'CAUGHT_ERR_TRAP'
}

@test "shdoc::file_has_description fallback reports absent header under strict mode" {
  local f="${BATS_TEST_TMPDIR}/misc_style_no_desc"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

trap 'echo err' ERR
echo hello
EOF
  run bash -c "
    set -Eeuo pipefail
    trap 'echo CAUGHT_ERR_TRAP >&2; exit 99' ERR
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/strings.bash'
    source '${SCRIPTS_DIR}/functions/shdoc.bash'
    if shdoc::file_has_description '${f}'; then
      exit 0
    else
      exit 1
    fi
  "
  assert_failure 1
  refute_output --partial 'CAUGHT_ERR_TRAP'
}

@test "shdoc::find_unannotated_functions clean when every helper is annotated" {
  local f="${BATS_TEST_TMPDIR}/s9"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description top
# @noargs

# @description does a
function a() {
  :
}

# @arg $1 x description
function b() {
  :
}
EOF
  run shdoc::find_unannotated_functions "${f}"
  assert_success
  assert_output ''
}

@test "shdoc::header_has_placeholder true for TODO in @description" {
  local f="${BATS_TEST_TMPDIR}/p1"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description TODO: describe what this script does.
# @noargs

set -Eeuo pipefail
EOF
  run shdoc::header_has_placeholder "${f}"
  assert_success
}

@test "shdoc::header_has_placeholder true for TODO in an @arg body" {
  local f="${BATS_TEST_TMPDIR}/p2"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description Sync the flatpaks.
# @arg $1 target TODO name this properly

set -Eeuo pipefail
EOF
  run shdoc::header_has_placeholder "${f}"
  assert_success
}

@test "shdoc::header_has_placeholder true for TODO on a continuation line" {
  local f="${BATS_TEST_TMPDIR}/p3"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description Sync the flatpaks.
#              TODO: document the --dry-run flag.
# @noargs

set -Eeuo pipefail
EOF
  run shdoc::header_has_placeholder "${f}"
  assert_success
}

@test "shdoc::header_has_placeholder false for TODO below the header window" {
  local f="${BATS_TEST_TMPDIR}/p4"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description Scaffold a new script.
# @noargs

set -Eeuo pipefail

cat > "$1" << 'INNER'
# @description TODO: describe what this script does.
INNER
EOF
  run shdoc::header_has_placeholder "${f}"
  assert_failure
}

@test "shdoc::header_has_placeholder true for TODO within the 30-line no-pragma window" {
  local f="${BATS_TEST_TMPDIR}/p5"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description TODO: describe this standalone script.
# @noargs

echo hi
EOF
  run shdoc::header_has_placeholder "${f}"
  assert_success
}

@test "shdoc::header_has_placeholder false for TODO past line 30 with no pragma" {
  local f="${BATS_TEST_TMPDIR}/p6"
  {
    printf '%s\n' '#!/usr/bin/env bash' '' '# @description A real description.' '# @noargs' ''
    local i
    for ((i = 0; i < 30; i++)); do printf '%s\n' "echo line ${i}"; done
    printf '%s\n' '# TODO: this is far past the window'
  } > "${f}"
  run shdoc::header_has_placeholder "${f}"
  assert_failure
}

@test "shdoc::header_has_placeholder false for TODO in prose before any tag" {
  local f="${BATS_TEST_TMPDIR}/p7"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash
# TODO: revisit this file layout
# @description A real description.
# @noargs

set -Eeuo pipefail
EOF
  run shdoc::header_has_placeholder "${f}"
  assert_failure
}

@test "shdoc::header_has_placeholder false for lowercase todo" {
  local f="${BATS_TEST_TMPDIR}/p8"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description Manage the todo list.
# @noargs

set -Eeuo pipefail
EOF
  run shdoc::header_has_placeholder "${f}"
  assert_failure
}

@test "shdoc::header_has_placeholder false for TODOS without word boundary" {
  local f="${BATS_TEST_TMPDIR}/p9"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description Print all TODOS found in the tree.
# @noargs

set -Eeuo pipefail
EOF
  run shdoc::header_has_placeholder "${f}"
  assert_failure
}

@test "shdoc::header_has_placeholder false for a clean header" {
  local f="${BATS_TEST_TMPDIR}/p10"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description Copy the kernel hardening sysctl file into /etc/sysctl.d.
# @noargs

set -Eeuo pipefail
EOF
  run shdoc::header_has_placeholder "${f}"
  assert_failure
}

@test "shdoc::header_has_placeholder dies with 0 args" {
  run shdoc::header_has_placeholder
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "shdoc::header_has_placeholder dies with 2 args" {
  run shdoc::header_has_placeholder a b
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "shdoc::find_unannotated_functions reports a namespaced function with no annotation" {
  local f="${BATS_TEST_TMPDIR}/lib.bash"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

function foo::unannotated() {
  echo hi
}
EOF
  run shdoc::find_unannotated_functions "${f}"
  assert_success
  assert_output 'foo::unannotated'
}

@test "shdoc::find_unannotated_functions stays quiet for an annotated namespaced function" {
  local f="${BATS_TEST_TMPDIR}/lib.bash"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description Do a thing.
# @noargs
function foo::annotated() {
  echo hi
}
EOF
  run shdoc::find_unannotated_functions "${f}"
  assert_success
  assert_output ''
}

@test "shdoc::find_unannotated_functions reports a namespaced function behind only a shellcheck directive" {
  local f="${BATS_TEST_TMPDIR}/lib.bash"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# shellcheck disable=SC2120
function foo::directive_only() {
  echo hi
}
EOF
  run shdoc::find_unannotated_functions "${f}"
  assert_success
  assert_output 'foo::directive_only'
}

@test "shdoc::find_unannotated_functions reports both namespaced and plain offenders" {
  local f="${BATS_TEST_TMPDIR}/lib.bash"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

function foo::one() {
  echo one
}

function plain_two() {
  echo two
}
EOF
  run shdoc::find_unannotated_functions "${f}"
  assert_success
  assert_line --index 0 'foo::one'
  assert_line --index 1 'plain_two'
}

@test "shdoc::find_placeholder_functions flags a bare TODO in a function @description" {
  local f="${BATS_TEST_TMPDIR}/lib.bash"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description TODO: describe what this does.
# @arg $1 thing
function foo::scaffolded() {
  echo hi
}
EOF
  run shdoc::find_placeholder_functions "${f}"
  assert_success
  assert_output 'foo::scaffolded'
}

@test "shdoc::find_placeholder_functions flags a TODO in an @arg body" {
  local f="${BATS_TEST_TMPDIR}/lib.bash"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description Do a thing.
# @arg $1 target TODO name this properly
function foo::argbody() {
  echo hi
}
EOF
  run shdoc::find_placeholder_functions "${f}"
  assert_success
  assert_output 'foo::argbody'
}

@test "shdoc::find_placeholder_functions allows a backticked TODO" {
  local f="${BATS_TEST_TMPDIR}/lib.bash"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description Match a word-bounded `TODO`, so `todo` and `TODOS` do not trip it.
# @noargs
function foo::documents_the_rule() {
  echo hi
}
EOF
  run shdoc::find_placeholder_functions "${f}"
  assert_success
  assert_output ''
}

@test "shdoc::find_placeholder_functions ignores lowercase todo" {
  local f="${BATS_TEST_TMPDIR}/lib.bash"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description Handle todo lists.
# @noargs
function foo::lowercase() {
  echo hi
}
EOF
  run shdoc::find_placeholder_functions "${f}"
  assert_success
  assert_output ''
}

@test "shdoc::find_placeholder_functions ignores TODOS without a word boundary" {
  local f="${BATS_TEST_TMPDIR}/lib.bash"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description Enumerate TODOS in a file.
# @noargs
function foo::plural() {
  echo hi
}
EOF
  run shdoc::find_placeholder_functions "${f}"
  assert_success
  assert_output ''
}

@test "shdoc::find_placeholder_functions ignores an underscore-joined TODO_MARKER" {
  local f="${BATS_TEST_TMPDIR}/lib.bash"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description Parse a TODO_MARKER token.
# @noargs
function foo::marker() {
  echo hi
}
EOF
  run shdoc::find_placeholder_functions "${f}"
  assert_success
  assert_output ''
}

@test "shdoc::find_placeholder_functions ignores a TODO in the function body" {
  local f="${BATS_TEST_TMPDIR}/lib.bash"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description Do a thing.
# @noargs
function foo::body_todo() {
  # TODO: handle the IPv6 case
  echo hi
}
EOF
  run shdoc::find_placeholder_functions "${f}"
  assert_success
  assert_output ''
}

@test "shdoc::find_placeholder_functions ignores a TODO separated by a blank line" {
  local f="${BATS_TEST_TMPDIR}/lib.bash"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# TODO: revisit this whole file layout

# @description Do a thing.
# @noargs
function foo::detached() {
  echo hi
}
EOF
  run shdoc::find_placeholder_functions "${f}"
  assert_success
  assert_output ''
}

@test "shdoc::find_placeholder_functions excludes main" {
  local f="${BATS_TEST_TMPDIR}/s1"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description TODO: describe this entry point.
function main() {
  echo hi
}
EOF
  run shdoc::find_placeholder_functions "${f}"
  assert_success
  assert_output ''
}

@test "shdoc::find_placeholder_functions reports every offending function" {
  local f="${BATS_TEST_TMPDIR}/lib.bash"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description TODO: describe this.
function foo::one() {
  echo one
}

# @description Fine.
function foo::two() {
  echo two
}

# @description TODO: and this.
function foo::three() {
  echo three
}
EOF
  run shdoc::find_placeholder_functions "${f}"
  assert_success
  assert_line --index 0 'foo::one'
  assert_line --index 1 'foo::three'
  refute_output --partial 'foo::two'
}

@test "shdoc::find_placeholder_functions flags a helper in a top-level script" {
  local f="${BATS_TEST_TMPDIR}/s1"
  cat > "${f}" << 'EOF'
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
  run shdoc::find_placeholder_functions "${f}"
  assert_success
  assert_output 'collect_things'
}

@test "shdoc::find_placeholder_functions emits nothing for a clean file" {
  local f="${BATS_TEST_TMPDIR}/lib.bash"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description Do a thing.
# @noargs
function foo::clean() {
  echo hi
}
EOF
  run shdoc::find_placeholder_functions "${f}"
  assert_success
  assert_output ''
}

@test "shdoc::find_placeholder_functions dies with 0 args" {
  run shdoc::find_placeholder_functions
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "shdoc::find_placeholder_functions dies with 2 args" {
  run shdoc::find_placeholder_functions a b
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "shdoc::header_has_placeholder allows a backticked TODO in the header" {
  local f="${BATS_TEST_TMPDIR}/s1"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

# @description Report a word-bounded `TODO`, which is what the scaffold emits.
# @noargs

set -Eeuo pipefail
IFS=$'\n\t'

echo hi
EOF
  run shdoc::header_has_placeholder "${f}"
  assert_failure
}

@test "shdoc::find_unannotated_functions propagates a failure of its awk" {
  # The caller in check-shdoc-headers routes this helper's stdout to a temp
  # file and reads emptiness as "clean", so a swallowed awk failure would
  # manufacture a clean verdict. The status must pass through.
  local f="${BATS_TEST_TMPDIR}/s-awk-fail"
  cat > "${f}" << 'EOF'
#!/usr/bin/env bash

function ns::helper() {
  echo hi
}
EOF
  path_shim::add 'awk' '#!/usr/bin/env bash
exit 7'
  run shdoc::find_unannotated_functions "${f}"
  assert_failure 7
  refute_output
}
