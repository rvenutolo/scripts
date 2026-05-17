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
