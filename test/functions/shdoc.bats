#!/usr/bin/env bats

setup() {
  load '../test_helper/common'
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
}

@test "shdoc::file_has_description dies with 2 args" {
  run shdoc::file_has_description a b
  assert_failure
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
  assert_failure
  [[ "${status}" -eq 1 ]] || {
    echo \"unexpected status: ${status}\"
    return 1
  }
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
}

@test "shdoc::header_has_placeholder dies with 2 args" {
  run shdoc::header_has_placeholder a b
  assert_failure
}
