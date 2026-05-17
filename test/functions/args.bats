#!/usr/bin/env bats

# shellcheck disable=SC2016 # $-tokens are literal text inside fixture shdoc headers

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
}

# Helper: assert that a check died with the standard "Expected <count>" message.
# $1 = expected count substring (e.g. "1 argument", "2 arguments", "no arguments")
assert_died_expecting() {
  assert_failure
  assert_output --partial "Expected $1"
}

# ---------- check_no_args ----------

@test "check_no_args: succeeds with 0 args" {
  run args::check_no_args
  assert_success
}

@test "check_no_args: dies with 1 arg" {
  run args::check_no_args 'a'
  assert_died_expecting 'no arguments'
}

@test "check_no_args: dies with 3 args" {
  run args::check_no_args 'a' 'b' 'c'
  assert_died_expecting 'no arguments'
}

# ---------- check_at_most_1_arg ----------

@test "check_at_most_1_arg: succeeds with 0 args" {
  run args::check_at_most_1_arg
  assert_success
}

@test "check_at_most_1_arg: succeeds with 1 arg" {
  run args::check_at_most_1_arg 'a'
  assert_success
}

@test "check_at_most_1_arg: dies with 2 args" {
  run args::check_at_most_1_arg 'a' 'b'
  assert_died_expecting 'at most 1 argument'
}

# ---------- check_exactly_1_arg ----------

@test "check_exactly_1_arg: dies with 0 args" {
  run args::check_exactly_1_arg
  assert_died_expecting 'exactly 1 argument'
}

@test "check_exactly_1_arg: succeeds with 1 arg" {
  run args::check_exactly_1_arg 'a'
  assert_success
}

@test "check_exactly_1_arg: succeeds with empty-string arg" {
  run args::check_exactly_1_arg ''
  assert_success
}

@test "check_exactly_1_arg: dies with 2 args" {
  run args::check_exactly_1_arg 'a' 'b'
  assert_died_expecting 'exactly 1 argument'
}

# ---------- check_at_least_1_arg ----------

@test "check_at_least_1_arg: dies with 0 args" {
  run args::check_at_least_1_arg
  assert_died_expecting 'at least 1 argument'
}

@test "check_at_least_1_arg: succeeds with 1 arg" {
  run args::check_at_least_1_arg 'a'
  assert_success
}

@test "check_at_least_1_arg: succeeds with 5 args" {
  run args::check_at_least_1_arg 'a' 'b' 'c' 'd' 'e'
  assert_success
}

# ---------- check_at_most_2_args ----------

@test "check_at_most_2_args: succeeds with 0 args" {
  run args::check_at_most_2_args
  assert_success
}

@test "check_at_most_2_args: succeeds with 2 args" {
  run args::check_at_most_2_args 'a' 'b'
  assert_success
}

@test "check_at_most_2_args: dies with 3 args" {
  run args::check_at_most_2_args 'a' 'b' 'c'
  assert_died_expecting 'at most 2 arguments'
}

# ---------- check_exactly_2_args ----------

@test "check_exactly_2_args: dies with 1 arg" {
  run args::check_exactly_2_args 'a'
  assert_died_expecting 'exactly 2 arguments'
}

@test "check_exactly_2_args: succeeds with 2 args" {
  run args::check_exactly_2_args 'a' 'b'
  assert_success
}

@test "check_exactly_2_args: dies with 3 args" {
  run args::check_exactly_2_args 'a' 'b' 'c'
  assert_died_expecting 'exactly 2 arguments'
}

# ---------- check_at_least_2_args ----------

@test "check_at_least_2_args: dies with 1 arg" {
  run args::check_at_least_2_args 'a'
  assert_died_expecting 'at least 2 arguments'
}

@test "check_at_least_2_args: succeeds with 2 args" {
  run args::check_at_least_2_args 'a' 'b'
  assert_success
}

@test "check_at_least_2_args: succeeds with 4 args" {
  run args::check_at_least_2_args 'a' 'b' 'c' 'd'
  assert_success
}

# ---------- check_at_most_3_args ----------

@test "check_at_most_3_args: succeeds with 3 args" {
  run args::check_at_most_3_args 'a' 'b' 'c'
  assert_success
}

@test "check_at_most_3_args: dies with 4 args" {
  run args::check_at_most_3_args 'a' 'b' 'c' 'd'
  assert_died_expecting 'at most 3 arguments'
}

# ---------- check_exactly_3_args ----------

@test "check_exactly_3_args: dies with 2 args" {
  run args::check_exactly_3_args 'a' 'b'
  assert_died_expecting 'exactly 3 arguments'
}

@test "check_exactly_3_args: succeeds with 3 args" {
  run args::check_exactly_3_args 'a' 'b' 'c'
  assert_success
}

@test "check_exactly_3_args: dies with 4 args" {
  run args::check_exactly_3_args 'a' 'b' 'c' 'd'
  assert_died_expecting 'exactly 3 arguments'
}

# ---------- check_at_least_3_args ----------

@test "check_at_least_3_args: dies with 2 args" {
  run args::check_at_least_3_args 'a' 'b'
  assert_died_expecting 'at least 3 arguments'
}

@test "check_at_least_3_args: succeeds with 3 args" {
  run args::check_at_least_3_args 'a' 'b' 'c'
  assert_success
}

# ---------- check_at_most_4_args ----------

@test "check_at_most_4_args: succeeds with 4 args" {
  run args::check_at_most_4_args 'a' 'b' 'c' 'd'
  assert_success
}

@test "check_at_most_4_args: dies with 5 args" {
  run args::check_at_most_4_args 'a' 'b' 'c' 'd' 'e'
  assert_died_expecting 'at most 4 arguments'
}

# ---------- check_exactly_4_args ----------

@test "check_exactly_4_args: dies with 3 args" {
  run args::check_exactly_4_args 'a' 'b' 'c'
  assert_died_expecting 'exactly 4 arguments'
}

@test "check_exactly_4_args: succeeds with 4 args" {
  run args::check_exactly_4_args 'a' 'b' 'c' 'd'
  assert_success
}

@test "check_exactly_4_args: dies with 5 args" {
  run args::check_exactly_4_args 'a' 'b' 'c' 'd' 'e'
  assert_died_expecting 'exactly 4 arguments'
}

# ---------- check_at_least_4_args ----------

@test "check_at_least_4_args: dies with 3 args" {
  run args::check_at_least_4_args 'a' 'b' 'c'
  assert_died_expecting 'at least 4 arguments'
}

@test "check_at_least_4_args: succeeds with 4 args" {
  run args::check_at_least_4_args 'a' 'b' 'c' 'd'
  assert_success
}

# ---------- no_args ----------

@test "no_args: true with 0 args" {
  run args::no_args
  assert_success
}

@test "no_args: false with 1 arg" {
  run args::no_args 'a'
  assert_failure
}

@test "no_args: false with empty-string arg" {
  run args::no_args ''
  assert_failure
}

@test "no_args: false with 3 args" {
  run args::no_args 'a' 'b' 'c'
  assert_failure
}

# ---------- has_num_args ----------

@test "has_num_args: dies with 0 args (missing expected count)" {
  run args::has_num_args
  assert_died_expecting 'at least 1 argument'
}

@test "has_num_args 0: true with 0 remaining" {
  run args::has_num_args 0
  assert_success
}

@test "has_num_args 0: false with 1 remaining" {
  run args::has_num_args 0 'a'
  assert_failure
}

@test "has_num_args 1: true with 1 remaining" {
  run args::has_num_args 1 'a'
  assert_success
}

@test "has_num_args 1: true with empty-string remaining" {
  run args::has_num_args 1 ''
  assert_success
}

@test "has_num_args 1: false with 0 remaining" {
  run args::has_num_args 1
  assert_failure
}

@test "has_num_args 1: false with 2 remaining" {
  run args::has_num_args 1 'a' 'b'
  assert_failure
}

@test "has_num_args 3: true with 3 remaining" {
  run args::has_num_args 3 'a' 'b' 'c'
  assert_success
}

@test "has_num_args 3: false with 2 remaining" {
  run args::has_num_args 3 'a' 'b'
  assert_failure
}

@test "has_num_args 3: false with 4 remaining" {
  run args::has_num_args 3 'a' 'b' 'c' 'd'
  assert_failure
}

# ---------- stdin_exists / check_for_stdin ----------

@test "stdin_exists: true when stdin is a heredoc" {
  run bash -c 'source "${SCRIPTS_DIR}/functions/args.bash"; args::stdin_exists' <<< 'data'
  assert_success
}

@test "check_for_stdin: succeeds when stdin is a heredoc" {
  run bash -c 'source "${SCRIPTS_DIR}/functions/args.bash"; args::check_for_stdin' <<< 'data'
  assert_success
}

# ---------- print_help ----------

write_fixture() {
  local -r path="$1"
  shift
  printf '%s\n' "$@" > "${path}"
}

@test "print_help: dies with 2 args" {
  run args::print_help 'a' 'b'
  assert_failure
  assert_output --partial 'Expected at most 1 argument'
}

@test "print_help: prints script name from path" {
  local fixture="${BATS_TEST_TMPDIR}/myscript"
  write_fixture "${fixture}" \
    '#!/usr/bin/env bash' \
    '' \
    '# @description Sample description.' \
    '' \
    'set -Eeuo pipefail'
  run args::print_help "${fixture}"
  assert_success
  assert_line --index 0 'myscript'
}

@test "print_help: renders @description" {
  local fixture="${BATS_TEST_TMPDIR}/myscript"
  write_fixture "${fixture}" \
    '#!/usr/bin/env bash' \
    '' \
    '# @description Does the thing.' \
    '' \
    'set -Eeuo pipefail'
  run args::print_help "${fixture}"
  assert_success
  assert_output --partial 'Does the thing.'
}

@test "print_help: renders @arg lines under Arguments" {
  local fixture="${BATS_TEST_TMPDIR}/myscript"
  write_fixture "${fixture}" \
    '#!/usr/bin/env bash' \
    '' \
    '# @description Test.' \
    '# @arg $1 input path to input' \
    '# @arg $2 mode operation mode' \
    '' \
    'set -Eeuo pipefail'
  run args::print_help "${fixture}"
  assert_success
  assert_output --partial 'Arguments:'
  assert_output --partial '$1 input path to input'
  assert_output --partial '$2 mode operation mode'
}

@test "print_help: @noargs renders without Arguments section" {
  local fixture="${BATS_TEST_TMPDIR}/myscript"
  write_fixture "${fixture}" \
    '#!/usr/bin/env bash' \
    '' \
    '# @description Test.' \
    '# @noargs' \
    '' \
    'set -Eeuo pipefail'
  run args::print_help "${fixture}"
  assert_success
  refute_output --partial 'Arguments:'
}

@test "print_help: renders @exitcode lines" {
  local fixture="${BATS_TEST_TMPDIR}/myscript"
  write_fixture "${fixture}" \
    '#!/usr/bin/env bash' \
    '' \
    '# @description Test.' \
    '# @exitcode 0 success' \
    '# @exitcode 1 failure' \
    '' \
    'set -Eeuo pipefail'
  run args::print_help "${fixture}"
  assert_success
  assert_output --partial 'Exit codes:'
  assert_output --partial '0 success'
  assert_output --partial '1 failure'
}

@test "print_help: renders @stdout and @stderr" {
  local fixture="${BATS_TEST_TMPDIR}/myscript"
  write_fixture "${fixture}" \
    '#!/usr/bin/env bash' \
    '' \
    '# @description Test.' \
    '# @stdout some output' \
    '# @stderr diagnostics' \
    '' \
    'set -Eeuo pipefail'
  run args::print_help "${fixture}"
  assert_success
  assert_output --partial 'Stdout:'
  assert_output --partial 'some output'
  assert_output --partial 'Stderr:'
  assert_output --partial 'diagnostics'
}

@test "print_help: renders @example block with continuation" {
  local fixture="${BATS_TEST_TMPDIR}/myscript"
  write_fixture "${fixture}" \
    '#!/usr/bin/env bash' \
    '' \
    '# @description Test.' \
    '# @example' \
    '#   myscript foo' \
    '#   myscript bar' \
    '' \
    'set -Eeuo pipefail'
  run args::print_help "${fixture}"
  assert_success
  assert_output --partial 'Example:'
  assert_output --partial 'myscript foo'
  assert_output --partial 'myscript bar'
}

@test "print_help: preserves description continuation lines" {
  local fixture="${BATS_TEST_TMPDIR}/myscript"
  write_fixture "${fixture}" \
    '#!/usr/bin/env bash' \
    '' \
    '# @description First line.' \
    '#   Continuation.' \
    '' \
    'set -Eeuo pipefail'
  run args::print_help "${fixture}"
  assert_success
  assert_output --partial 'First line.'
  assert_output --partial 'Continuation.'
}

@test "print_help: stops parsing at first non-comment line" {
  local fixture="${BATS_TEST_TMPDIR}/myscript"
  write_fixture "${fixture}" \
    '#!/usr/bin/env bash' \
    '' \
    '# @description Real.' \
    '' \
    'set -Eeuo pipefail' \
    '# @description Should not be parsed.'
  run args::print_help "${fixture}"
  assert_success
  assert_output --partial 'Real.'
  refute_output --partial 'Should not be parsed.'
}

# ---------- handle_help_flag ----------

@test "handle_help_flag: no-op when no help arg present" {
  run bash -c 'source "${SCRIPTS_DIR}/functions/args.bash"; args::handle_help_flag "foo" "bar"; echo "continued"'
  assert_success
  assert_output 'continued'
}

@test "handle_help_flag: exits 0 and prints help on --help" {
  local fixture="${BATS_TEST_TMPDIR}/myscript"
  write_fixture "${fixture}" \
    '#!/usr/bin/env bash' \
    '' \
    '# @description Sample.' \
    '' \
    'set -Eeuo pipefail' \
    '# shellcheck disable=SC1091' \
    'source "${SCRIPTS_DIR}/functions.bash"' \
    'args::handle_help_flag "$@"' \
    'echo "did-not-exit"'
  chmod +x "${fixture}"
  run "${fixture}" --help
  assert_success
  assert_output --partial 'myscript'
  assert_output --partial 'Sample.'
  refute_output --partial 'did-not-exit'
}

@test "handle_help_flag: exits 0 and prints help on -h" {
  local fixture="${BATS_TEST_TMPDIR}/myscript"
  write_fixture "${fixture}" \
    '#!/usr/bin/env bash' \
    '' \
    '# @description Sample.' \
    '' \
    'set -Eeuo pipefail' \
    '# shellcheck disable=SC1091' \
    'source "${SCRIPTS_DIR}/functions.bash"' \
    'args::handle_help_flag "$@"' \
    'echo "did-not-exit"'
  chmod +x "${fixture}"
  run "${fixture}" -h
  assert_success
  assert_output --partial 'myscript'
  refute_output --partial 'did-not-exit'
}

@test "handle_help_flag: --help recognized anywhere in arg list" {
  local fixture="${BATS_TEST_TMPDIR}/myscript"
  write_fixture "${fixture}" \
    '#!/usr/bin/env bash' \
    '' \
    '# @description Sample.' \
    '' \
    'set -Eeuo pipefail' \
    '# shellcheck disable=SC1091' \
    'source "${SCRIPTS_DIR}/functions.bash"' \
    'args::handle_help_flag "$@"' \
    'echo "did-not-exit"'
  chmod +x "${fixture}"
  run "${fixture}" foo bar --help baz
  assert_success
  assert_output --partial 'Sample.'
  refute_output --partial 'did-not-exit'
}
